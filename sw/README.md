UDP Benchmark
=============
This application is used to test the performance of the open source FPGA UDP/IP core udp_ip_stack present on opencores.org.
In particular this application allows to test the packet loss rate and the transmission data rate both from the PC to the FPGA
and from the FPGA to the PC.

The speed performance strongly depends on the software PC implementation, in this case on the Qt implementation.

During the FPGA to PC test, the FPGA sends packets at its maximum speed (125MB/s) so that the Qt application looses some packets
thus providing a wrong packet loss measure. In fact by using wireshark its possible to see that all the packets are received correctly by the
PC. By setting the delay between two subsequent transmission (in clock cycles) in the FPGA it's possible to obtain a loss rate of 0%
by reducing the maximum data rate. This is probably due to the elaboration time of each packet introduced by Qt.

Documentation
=============

To consult the API documentation open one of the following files:

* **index.html** located in the folder _doc/html/_ (Recommended)
* **refman.pdf** in the folder _doc/latex/_ (A copy of refman.pdf has been placed in the root folder for convenience.
                 It should be updated every time the documentation is regenerated.)

To update the Doxygen documentation run the following command from the root folder:

    doxygen Doxygen

then, to generate the PDF manual (refman.pdf), execute the following command from the folder doc/latex:

    make

One line command to regenerate the documentation under Linux and MAC:

    doxygen Doxygen && make -C doc/latex/ && cp doc/latex/refman.pdf refman.pdf

Author
======

Simone Gaiarin (simgunz@gmail.com)

License
=======

This software is released under the [GPLv3 license](www.gnu.org/copyleft/gpl.html).

References
==========

- [UDP/IP core official site](http://opencores.org/project,udp_ip_stack)
- [UDP/IP core improved version](https://github.com/simgunz/udp_ip_stack) containing all the Virtex 6 MAC layer components
