import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


async def reset_dut(dut):
    """Start 10 ns clock, initialize all NPU inputs, hold reset 8 cycles."""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    dut.rst.value              = 1
    dut.s_axil_awaddr.value    = 0
    dut.s_axil_awvalid.value   = 0
    dut.s_axil_wdata.value     = 0
    dut.s_axil_wvalid.value    = 0
    dut.s_axil_bready.value    = 0
    dut.seq_arready.value      = 0
    dut.seq_rdata.value        = 0
    dut.seq_rvalid.value       = 0
    dut.seq_rlast.value        = 0
    dut.seq_rresp.value        = 0
    dut.dma_arready.value      = 0
    dut.dma_rdata.value        = 0
    dut.dma_rvalid.value       = 0
    dut.dma_rlast.value        = 0
    dut.dma_rresp.value        = 0
    dut.wt_arready.value       = 0
    dut.wt_rdata.value         = 0
    dut.wt_rvalid.value        = 0
    dut.wt_rlast.value         = 0
    dut.wt_rresp.value         = 0
    dut.st_awready.value       = 0
    dut.st_wready.value        = 0
    dut.st_bresp.value         = 0
    dut.st_bvalid.value        = 0

    await ClockCycles(dut.clk, 8)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


class AXILiteMaster:
    """Drives the NPU's AXI-Lite slave (s_axil_*) write channel."""

    def __init__(self, dut):
        self._dut = dut

    async def write(self, addr, data):
        dut = self._dut
        await RisingEdge(dut.clk)
        dut.s_axil_awaddr.value  = addr
        dut.s_axil_awvalid.value = 1
        dut.s_axil_wdata.value   = data
        dut.s_axil_wvalid.value  = 1
        dut.s_axil_bready.value  = 1

        while not (dut.s_axil_awready.value and dut.s_axil_wready.value):
            await RisingEdge(dut.clk)

        await RisingEdge(dut.clk)
        dut.s_axil_awvalid.value = 0
        dut.s_axil_wvalid.value  = 0

        while not dut.s_axil_bvalid.value:
            await RisingEdge(dut.clk)

        assert dut.s_axil_bresp.value == 0, \
            f"AXI-Lite write BRESP={dut.s_axil_bresp.value} (expected OKAY)"
        await RisingEdge(dut.clk)
        dut.s_axil_bready.value = 0


class AXI4ReadSlave:
    """Responds to one AXI4 read channel (seq, dma, or wt).

    mem: dict mapping word_addr (byte_addr >> 4) to 128-bit int value.
    data_bits: 32 for seq channel, 128 for dma/wt.
    delay_rng: random.Random instance; inserts randint(0,3) cycles before arready.
    """

    def __init__(self, dut, prefix, mem, data_bits=128, delay_rng=None):
        self._clk      = dut.clk
        self._arvalid  = getattr(dut, f'{prefix}_arvalid')
        self._arready  = getattr(dut, f'{prefix}_arready')
        self._araddr   = getattr(dut, f'{prefix}_araddr')
        self._arlen    = getattr(dut, f'{prefix}_arlen')
        self._rdata    = getattr(dut, f'{prefix}_rdata')
        self._rvalid   = getattr(dut, f'{prefix}_rvalid')
        self._rlast    = getattr(dut, f'{prefix}_rlast')
        self._rresp    = getattr(dut, f'{prefix}_rresp')
        self._rready   = getattr(dut, f'{prefix}_rready')
        self.mem       = mem
        self._bits     = data_bits
        self._rng      = delay_rng

    async def start(self):
        cocotb.start_soon(self._run())

    async def _run(self):
        while True:
            # wait for AR valid
            await RisingEdge(self._clk)
            if not self._arvalid.value:
                continue

            # optional stall before arready
            if self._rng:
                for _ in range(self._rng.randint(0, 3)):
                    await RisingEdge(self._clk)

            word_addr = int(self._araddr.value) >> 4
            beats     = int(self._arlen.value) + 1

            self._arready.value = 1
            await RisingEdge(self._clk)
            self._arready.value = 0

            for b in range(beats):
                if self._bits == 32:
                    # seq channel: all 4 beats are 32-bit slices of the same 128-bit word
                    raw = self.mem.get(word_addr, 0)
                    self._rdata.value = (raw >> (b * 32)) & 0xFFFF_FFFF
                else:
                    # 128-bit channels: each beat is a separate 128-bit word
                    raw = self.mem.get(word_addr + b, 0)
                    self._rdata.value = raw

                self._rresp.value = 0
                self._rlast.value = 1 if b == beats - 1 else 0
                self._rvalid.value = 1

                # AXI4 §A3.2.1: hold valid/data/last until handshake (rvalid && rready).
                # Was: drive for one cycle then drop. That violated the protocol
                # whenever the master toggled rready between beats (DMA COEFF_LOAD path).
                while True:
                    await RisingEdge(self._clk)
                    if self._rready.value:
                        break

                self._rvalid.value = 0
                self._rlast.value  = 0


class AXI4WriteSlave:
    """Accepts the NPU's AXI4 write channel (st_*).

    delay_rng: random.Random instance; inserts randint(0,3) cycles before wready per beat.
    store_words: list of 128-bit ints captured in order.
    """

    def __init__(self, dut, delay_rng=None):
        self._clk      = dut.clk
        self._awvalid  = dut.st_awvalid
        self._awready  = dut.st_awready
        self._awlen    = dut.st_awlen
        self._wdata    = dut.st_wdata
        self._wvalid   = dut.st_wvalid
        self._wready   = dut.st_wready
        self._wlast    = dut.st_wlast
        self._bvalid   = dut.st_bvalid
        self._bready   = dut.st_bready
        self._bresp    = dut.st_bresp
        self._rng      = delay_rng
        self.store_words = []

    async def start(self):
        cocotb.start_soon(self._run())

    async def _run(self):
        while True:
            await RisingEdge(self._clk)
            if not self._awvalid.value:
                continue

            beats = int(self._awlen.value) + 1
            self._awready.value = 1
            await RisingEdge(self._clk)
            self._awready.value = 0

            for _ in range(beats):
                # optional stall before wready
                if self._rng:
                    for _ in range(self._rng.randint(0, 3)):
                        await RisingEdge(self._clk)

                while not self._wvalid.value:
                    await RisingEdge(self._clk)

                self.store_words.append(int(self._wdata.value))
                self._wready.value = 1
                await RisingEdge(self._clk)
                self._wready.value = 0

            self._bresp.value  = 0
            self._bvalid.value = 1
            while not self._bready.value:
                await RisingEdge(self._clk)
            await RisingEdge(self._clk)
            self._bvalid.value = 0
