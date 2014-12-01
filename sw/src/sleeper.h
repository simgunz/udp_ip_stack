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
 * \file sleeper.h
 *
 * Contains the interface of the Sleeper class.
 */

#ifndef SLEEPER_H
#define SLEEPER_H

#include <QThread>

/*!
 * The Sleeper class provides an easy way to suspend a parent process for the specified number of
 * microseconds.
 *
 * It acts like the usleep() function of c but it wraps this function inside a QThread so that
 * it can be used in a parent Qt application.
 */
class Sleeper : public QThread
{
    Q_OBJECT

public:

    /*!
     * Default constructor.
     */
    explicit Sleeper(QObject *parent = 0);

    /*!
     * Suspend the QThread process for the specified number of microseconds.
     *
     * \param usecs The number of microseconds that the process should sleep.
     */
    static void sleep(int usecs);        
};

#endif // SLEEPER_H
