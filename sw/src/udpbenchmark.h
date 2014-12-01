/****************************************************************************
* Copyright (C) 2014 by QuantumFuture research group (University of Padova) *
* Author: Simone Gaiarin <simgunz@gmail.com>                                *
*                                                                           *
* This program is free software; you can redistribute it and/or modify      *
* it under the terms of the GNU General Public License as published by      *
* the Free Software Foundation; either version 3 of the License, or         *
* (at your option) any later version.                                       *
*                                                                           *
* This program is distributed in the hope that it will be useful,           *
* but WITHOUT ANY WARRANTY; without even the implied warranty of            *
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             *
* GNU General Public License for more details.                              *
*                                                                           *
* You should have received a copy of the GNU General Public License         *
* along with this program; if not, see <http://www.gnu.org/licenses/>.      *
****************************************************************************/

/*!
 * \file udpbenchmark.h
 *
 * Contains the interface of the UDPBenchmark class.
 */

#ifndef UDPBENCHMARK_H
#define UDPBENCHMARK_H

#include <QHostAddress>
#include <QMainWindow>

class QSocketNotifier;
class QTime;
class QUdpSocket;

namespace Ui {
    class UDPBenchmark;
}

/*!
 * The UDPBenchmark class provides a graphical interface to perform a speed and loss rate test on
 * the Vitrtex 6 UDP/IP core.
 *
 * The program can perform the following two tests:
 * - **PC>FPGA** This test sends a certain amount of packets to the FPGA and measures the throughput in MB/s
 *   by measuring the time required to finish the trasnmission. Moreover it shows the percentual loss rate
 *   by comparing the number of sent packets with the number of received packets by the FPGA, which send back to the PC
 *   a packet containing this information when requested.
 * * - **FPGA>PC** This test requires to the FPGA to send a certain amount of packets, measure the throughput in MB/s
 *   and evaluates the loss rate by comparing the received packets with the number of expected packets.
 *
 * \bug Under Windows the software is not able to use the QSocketNotifier object (or some workaround may be implemented
 * as specified in the API page of QSocketNotifier), because of this the PC>FPGA is performed by sending the UDP packets
 * one after the other and the Sleeper calss is used to suspend the process for some milliseconds in order to not overload
 * the network layer, which implies a packet loss. The method startPCToFpgaTest has two different implementations in Windows
 * Unix (using compiler the #if compiler directive).
 *
 * \bug Under Windows the readPendingDatagram() method is currently never activated so that it's impossible to read any packets coming from
 * the FPGA. Because of this all the test measures won't be displayed. In any case it's possible to use Wireshark to check
 * if any packet has been lost during the test thus doing a manaul test. This bug can be solved with some workarounds.
 */
class UDPBenchmark : public QMainWindow
{
    Q_OBJECT
    
public:

    /*!
     * Enumerates the possible types of the test in progress.
     *
     * The program can be in an Idle state or one of the two tests PC>FPGA or FPGA>PC
     * can be in progress.
     */
    enum TestType {
        Idle,
        PcToFpga,
        FpgaToPc
    };

    /*!
     * Default constructor.
     *
     * Initializes the UDP socket, creates a dummy UDP package containing a #MTU bytes.
     *
     * \param The QWidget this object is parented to.
     */
    explicit UDPBenchmark(QWidget *parent = 0);

    /*!
     * Deconstructor.
     */
    ~UDPBenchmark();

    //! Constant defining the maximum data bytes an UDP packet can contains.
    static const int MTU = 1472;

    //! Constant defining the port on which the PC listen for incoming UDP packets
    static const quint16 m_LocalPort = 0x6af0;

    //! Constant defining the port on which the FPGA listen for incoming UDP packets
    static const quint16 m_fpgaPort = 0x84be;

private slots:

    /*!
     * Sets the FPGA IP address to which send the UDP packets from the UI form.
     *
     * This method is automatically invoked each time the user edit the FPGA IP address form in
     * the user interface.
     *
     * \param address A string containing the address in the form XXX.XXX.XXX.XXX.
     */
    void setFpgaAddress(QString address);

    /*!
     * Sets the FPGA IP address to which send the UDP packets from the UI form.
     *
     * This method is automatically invoked each time the user edit the FPGA IP address form in
     * the user interface.
     *
     * \param The number of packets to be sent in the test.
     */
    void setPktNum(int num);

    /*!
     * Reads the incoming UDP packets and elaborates them according to the test in progress.
     *
     * This method is automatically activated each time an UDP packets has arrived to the UDP
     * socket on the specified port.
     * - **PC>FPGA test** When this test is in progress the FPGA send a packet containing the
     * number of packets that it has received. This number is used to compute the packet loss,
     * which is then displayed to the user. To request this packet to the FPGA, a packet containing
     * the byte 'BB' must be sent to the FPGA.
     * - **FPGA>PC test**  When this test is in progress a counter is incremented each time a packet
     * arrives. A packet with first byte equal to 'DD' marks the end of the test.
     *
     * \warning During the FPGA>PC test, if the last packet is lost the test won't produce any results, so it must
     * be re-run again.
     */
    void readPendingDatagrams();

    /*!
     * Initialize the PC>FPGA test.
     *
     * Resets the loss rate and data rate labels in the UI, resets the local packet counter and the FPGA packet counter
     * (by sending the byte 'AA'), starts the timer to measures the data rate.
     *
     * - **Linux** Enables the QSocketNotifier in order to subsequently let the keepSending() method send all the
     * test packets.
     * - **Windows** Sends all the UDP packets to the FPGA waiting a certain amount of time between each transmission by
     * using the Sleeper:sleep() method. Finally displays the test results on the UI.
     */
    void startPcToFpgaTest();

#ifndef Q_OS_WIN32

    /*!
     * Sends an UDP packet to the FPGA everytime it's activated until reaching the max number of packets to be sent.
     *
     * This method is activated  by the 'activated' signal of the QSocketNotifier each time the network layer is ready
     * to receive new packets. Using this approach there won't be any packet loss due to network overload.
     *
     * This method is compiled only under Linux.
     */
    void keepSending();

    /*!
     * Terminates the PC>FPGA test.
     *
     * Computes and displays in the UI the data rate. By sending the byte 'BB' to the FPGA the software requires the number
     * of received packets by the FPGA. The response packet is
     * catched by readPendingDatagrams() and the loss rate label is set.
     */
    void endPcToFpgaTest();

#endif

    /*!
     * Initialize the FPGA>PC test.
     *
     * Resets the loss rate and data rate labels in the UI, resets the local packet counter and the FPGA packet counter
     * (by sending the byte 'AA'), starts the timer to measures the data rate.
     * Finally it send a packet to the FPGA to begin the test, to set the number of packets to be sent and to
     * set the number of clock cycles the FPGA should wait between two subsequent packet transmission.
     *
     * Packet format: CCXXXXXXXXYYYYYYYY
     * - CC byte that marks the start of the test
     * - XXXXXXXX hexadecimal representation padded with zeros of the number of packets the FPGA should send
     * - YYYYYYYY hexadecimal representation padded with zeros of the number of clock cycles the FPGA should
     * wait between subsequent packet transmission
     */
    void startFpgaToPcTest();

    /*!
     * Terminates the FPGA>PC test.
     *
     * Computes and displays in the UI the data rate and the data loss.
     */
    void endFpgaToPcTest();

private:

    //! Pointer to the main window object used to access the ui elements.
    Ui::UDPBenchmark *ui;

    //! UDP socket used to perform the communication.
    QUdpSocket *m_udpSocket;

#ifndef Q_OS_WIN32
    //! Socket notifier used in linux to trasmit the packets at a safe rate.
    QSocketNotifier *m_notifier;
#endif

    //! The type of the test in progress.
    TestType m_currentTestType;

    //! The dummy bytes that are sent by the PC in each UDP packet.
    QByteArray m_defaultData;

    //! The UDP packet destination address.
    QHostAddress m_fpgaAddress;

    //! Number of packets to be sent in the test (used in both tests).
    int m_pktNum;

    //! Number of packets already transmitted to FPGA (PC>FPGA).
    int m_pktCountTx;

    //! Number of packets already received from FPGA (FPGA>PC).
    int m_pktCountRx;

    //! Timer used to compute the data rate.
    QTime *m_benchTimer;
};

#endif // UDPBENCHMARK_H
