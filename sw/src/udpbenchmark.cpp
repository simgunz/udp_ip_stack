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
 * \file udpbenchmark.cpp
 *
 * Contains the implementation of the UDPBenchmark class.
 */

#include "udpbenchmark.h"
#include "ui_udpbenchmark.h"

#include "sleeper.h"

#include <QByteArray>
#include <QSocketNotifier>
#include <QTime>
#include <QUdpSocket>

UDPBenchmark::UDPBenchmark(QWidget *parent) :
    QMainWindow(parent),
    ui(new Ui::UDPBenchmark),
    m_currentTestType(Idle)
{
    //Setup the user interface
    ui->setupUi(this);

    //Set default values from ui form
    m_fpgaAddress = QHostAddress(ui->leFpgaAddress->text());
    m_pktNum = ui->sbPktNum->value();

    //Setup the UDP connection with the FPGA
    m_udpSocket = new QUdpSocket(this);
    m_udpSocket->setSocketOption(QAbstractSocket::LowDelayOption, true);
    //Bind the socket to a port in order to receive only the UDP packets intended to that port.
    //If the port is already used by another application (e.g. if multiple instances have been launched)
    //the software may not work.
    if (m_udpSocket->bind(m_LocalPort) == false) {
        qDebug() << "UDP socket not bounded. The program might not work correctly.";
    }

#ifndef Q_OS_WIN32
    //Create a SocketNotifier object. This object emits an activated signal when the network is ready to accept
    //more packets. So we connect this signal to the method keepSending in order to send packets automatically
    //only when the network is ready, otherwise if we send all the UDP packets on after the other at the maximum speed
    //they would probably be lost.
    //The notifier must be enabled only during the PC to FPGA test otherwise every time the network is ready to receive packets
    //the class keeps sending packets.
    m_notifier = new QSocketNotifier(m_udpSocket->socketDescriptor(), QSocketNotifier::Write);
    m_notifier->setEnabled(false);
#endif

    //Create the QTime object
    m_benchTimer = new QTime();

    //Generate a dummy UDP packet of the size specified by MTU (1472 max allowed by ehternet protocol)
    for (int i=0; i< MTU; i++) {
        m_defaultData.append(QByteArray::fromHex("FE"));
    }

    //Connect signals and slots
    QObject::connect(ui->leFpgaAddress, SIGNAL(textEdited(QString)), this, SLOT(setFpgaAddress(QString)));
    QObject::connect(ui->sbPktNum, SIGNAL(valueChanged(int)), this, SLOT(setPktNum(int)));
    QObject::connect(ui->pbRxStart, SIGNAL(clicked()), this, SLOT(startPcToFpgaTest()));
    QObject::connect(ui->pbTxStart, SIGNAL(clicked()), this, SLOT(startFpgaToPcTest()));
    QObject::connect(m_udpSocket, SIGNAL(readyRead()), this, SLOT(readPendingDatagrams()));
#ifndef Q_OS_WIN32
    QObject::connect(m_notifier,SIGNAL(activated(int)), this, SLOT(keepSending()));
#endif
}

UDPBenchmark::~UDPBenchmark()
{
    delete ui;
}

void UDPBenchmark::setFpgaAddress(QString address)
{
    m_fpgaAddress = address;
}

void UDPBenchmark::setPktNum(int num)
{
    m_pktNum = num;
}

void UDPBenchmark::readPendingDatagrams()
{

    bool ok;
    QByteArray datagram;
    QHostAddress sender;
    quint16 senderPort;


    while(m_udpSocket->hasPendingDatagrams()) {
        //Read the incoming packet
        datagram.resize(m_udpSocket->pendingDatagramSize());
        m_udpSocket->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);

        if(m_currentTestType == PcToFpga) {
            //The Fpga was supposed to send us the number of packet it has received
            int correct = datagram.toHex().toInt(&ok, 16);
            double percentCorrectPkts = 100*double(m_pktNum - correct)/m_pktNum;
            //Set the loss result in the UI label
            ui->lbLossRx->setText(QString("%1 \%").arg(percentCorrectPkts));
            m_currentTestType = Idle;
        } else {
            //FPGA>PC test. Increase the counter each time a packet arrives.
            QString data = QString(datagram.left(1).toHex());
            m_pktCountRx++;
            if(data == "dd") {
                endFpgaToPcTest();
            }
        }
    }
}

#ifndef Q_OS_WIN32
void UDPBenchmark::startPcToFpgaTest()
{
    //Set the current test type to inform which kind of packets expect from the FPGA
    m_currentTestType = PcToFpga;

    //Reset test results labels in the UI
    ui->lbDataRx->setText("NaN");
    ui->lbLossRx->setText("NaN");

    //Reset the number of sent packets
    m_pktCountTx = 0;

    //Reset the packet counter in the FPGA (used to count the received packets)
    m_udpSocket->writeDatagram(QByteArray::fromHex("AA"), m_fpgaAddress, m_fpgaPort);        

    //Start measuring the transmission duration time used to calculate the bit rate
    m_benchTimer->start();

    //Enable the socket notifier to begin send data to the FPGA
    m_notifier->setEnabled(true);    

    statusBar()->showMessage(QString("PC > FPGA test started"), 800);
}

void UDPBenchmark::keepSending()
{    
    if (m_pktCountTx < m_pktNum) {
         m_udpSocket->writeDatagram(m_defaultData, m_fpgaAddress, m_fpgaPort);
    } else {
        endPcToFpgaTest();
    }
    m_pktCountTx++;
}

void UDPBenchmark::endPcToFpgaTest()
{
    //Disable the socket notifier to stop send data to the FPGA
    m_notifier->setEnabled(false);    

    //Compute and display the transmission bit rate
    double benchTime = m_benchTimer->elapsed()/1000.0;
    ui->lbDataRx->setText(QString("%1 MB/s").arg((m_pktNum*MTU/benchTime)/(1024*1024),4,'f'));

    //Request a report on the received packet to the FPGA. The readPendingDatagram method will display the results.
    m_udpSocket->writeDatagram(QByteArray::fromHex("BB"), m_fpgaAddress, m_fpgaPort);

    statusBar()->showMessage(QString("%1 packet sent to the FPGA").arg(m_pktNum) , 800);
}
#else
void UDPBenchmark::startPcToFpgaTest()
{
    //Set the current test type to inform which kind of packets expect from the FPGA
    m_currentTestType = PcToFpga;

    //Reset test results labels in the UI
    ui->lbDataRx->setText("NaN");
    ui->lbLossRx->setText("NaN");

    //Reset the number of sent packets
    m_pktCountTx = 0;

    //Reset the packet counter in the FPGA (used to count the received packets)
    m_udpSocket->writeDatagram(QByteArray::fromHex("AA"), m_fpgaAddress, m_fpgaPort);

    //Start measuring the transmission duration time used to calculate the bit rate
    m_benchTimer->start();

    //send data to the FPGA
    for (int i=0; i<m_pktNum; i++) {
         m_udpSocket->writeDatagram(m_defaultData, m_fpgaAddress, m_fpgaPort);
         Sleeper::sleep(1);
    }

    //Compute and display the transmission bit rate
    double benchTime = m_benchTimer->elapsed()/1000.0;
    ui->lbDataRx->setText(QString("%1 MB/s").arg((m_pktNum*MTU/benchTime)/(1024*1024),4,'f'));

    //Request a report on the received packet to the FPGA. The readPendingDatagram method will display the results.
    m_udpSocket->writeDatagram(QByteArray::fromHex("BB"), m_fpgaAddress, m_fpgaPort);

    statusBar()->showMessage(QString("%1 packet sent to the FPGA").arg(m_pktNum) , 800);
}
#endif
void UDPBenchmark::startFpgaToPcTest()
{    
    //Set the current test type to inform which kind of packets expect from the FPGA
    m_currentTestType = FpgaToPc;

    //Reset test results labels in the UI
    ui->lbDataTx->setText("NaN");
    ui->lbLossTx->setText("NaN");

    //Reset the number of received packets
    m_pktCountRx = 0;

    //Reset the packet counter in the FPGA (used to count the sent packets)
    m_udpSocket->writeDatagram(QByteArray::fromHex("AA"), m_fpgaAddress, m_fpgaPort);

    //Mark start of Tx Test (CC) and set the number of packets the FPGA should send (next 4 bytes)
    //The command is in the form CCXXXXXXXXYYYYYYYY where the X are the hexadecimal representation padded with zeros
    //of the number of packets the FPGA should send, and Y are the hexadecimal representation padded with zeros
    //of the number of clock cycles the FPGA should wait between subsequent packet transmission
    QString command = QString("CC") + QString::number(m_pktNum, 16).rightJustified(8,QChar('0'))
            + QString::number(ui->sbTxDelay->value(), 16).rightJustified(8,QChar('0'));
    //From the QString we extract the char* string and we create a QByteArray object
    QByteArray commandHexEncoded(command.toStdString().c_str());

    //Start measuring the transmission duration time used to calculate the bit rate
    m_benchTimer->start();

    m_udpSocket->writeDatagram(QByteArray::fromHex(commandHexEncoded) , m_fpgaAddress, m_fpgaPort);

    statusBar()->showMessage(QString("FPGA > PC test started"), 800);
}

void UDPBenchmark::endFpgaToPcTest()
{
    //Compute and display the transmission bit rate
    double benchTime = m_benchTimer->elapsed()/1000.0;
    ui->lbDataTx->setText(QString("%1 MB/s").arg((m_pktNum*MTU/benchTime)/(1024*1024),4,'f'));

    m_currentTestType = Idle;

    //Set the loss result in the UI label
    ui->lbLossTx->setText(QString("%1\%").arg( 100*(1 - float(m_pktCountRx)/m_pktNum) ));
}
