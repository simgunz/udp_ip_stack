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
 * \file main.cpp
 *
 * Contains the main of the UDPBenchmark project.
 */

#include "udpbenchmark.h"

#include <QApplication>

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    UDPBenchmark w;
    w.show();
    
    return a.exec();
}
