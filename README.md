# Exploring the Raft Consensus Algorithm in Ruby

This repository contains code that will (probably) end up some day into a real
set of Ruby objects that will be runnable and able to establish a consensus and
replicate/share data across all the nodes.

## Rationale
It is under development and won't be release anytime soon. The code could be a
little rough on the edges as it's basically a very large file, but here's the
main idea:

1. Each node must be independant.
2. Nodes can be run with threads within the same Ruby VM or could be run within
   separate processes.
3. The current communication mechanism is `DRb`. `DRb` is a built-in protocol
   that is really easy to setup but it should be made replaceable by `ZeroMQ`,
   `RabbitMQ`, `Thrift`, `ProtoBuf`, ... any other communication layer.

## TODO

There's almost no structure, but the Proof of Concept is working:

* nodes are talking to each other
* nodes can elect a leader
* candidates and followers know how to become leaders if needed
* a node can be killed and other nodes can proceed to another consensus


### What should be done

* [ ] Extract nodes
* [ ] Extract communication layer
* [ ] Extract launcher
* [ ] Ensure concurrence/parallelism is OK (Tested with MRI only)


## License

GPLv3 until a potential release. It will end up LGPLv3 or MIT.
