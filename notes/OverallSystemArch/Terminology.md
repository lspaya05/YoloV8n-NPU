# Terminology
Sourced from: *Computer Architecture a Quantitative Approach 7th  Edition*
## General Terms
| Term | Acronym | Short Explanation |
| :--- | :---: | :--- |
| Domain-specific architectures | DSA | Special-purpose processor designed for a particular domain. Relies on other processors to handle processing outside that domain. |
| Intellectual Property Block | IP | Portable design block that can be integrated into an SoC. Enables a marketplace where organizations offer IP to others who compose them into SoCs. |
| System on Chip | SoC | A chip that integrates all the components of a computer; commonly found in Personal Mobile Devices (PMDs). |

## Deep Neural Network Terms
| Term | Acronym | Short Explanation |
| :--- | :---: | :--- |
| Activation | --- | Result of "activating" the artificial neuron; the output of the nonlinear functions. |
| Batch | --- | A collection of datasets processed together to lower the cost of fetching weights. |
| Convolutional Neural Network | CNN | A DNN that takes as inputs a set of nonlinear functions of spatially nearby regions of outputs from the prior layer, which are multiplied by the weights. |
| Deep Neural Network | DNN | A sequence of layers that are collections of artificial neurons, which consist of a nonlinear function applied to products of weights times the outputs of the prior layer. |
| Inference | --- | The production phase of DNNs; also called serving. |
| MultiLayer Perceptron | MLP | A DNN that takes as inputs a set of nonlinear functions of all outputs from the prior layer multiplied by the weights. These layers are called fully connected. |
| Rectified Linear Unit | ReLU | A nonlinear function that performs F(X) = max(x, 0). Other popular nonlinear functions are "sigmoid" and hyperbolic tangent (tanh). |
| Recurrent Neural Network | RNN | A DNN whose inputs are from the prior layer and the previous state|
| Training | --- | The development phase of DNNs; also called learning. |
| Transformer | --- | A DNN that relies on an attention mechanism to provide the context for positions in the input sequence. Like RNNs, it is popular for natural language translation and text summarization, but unlike RNNs it processes the inputs all at once rather than sequentially. This change means the operations can occur in parallel, so it processes much larger data. |
| Weights | --- | The values learned during training that are applied to inputs; also called parameters. |
| Large Language Model | LLM | Also known as Frontier models, LLMs are based on the decode phase of the transformer model and typically have billions to trillions of parameters. |

## Architectural Terms
| Term | Acronym | Short Explanation |
| :--- | :---: | :--- |
| Scratch Pad Memory | 
| Systolic Array | 