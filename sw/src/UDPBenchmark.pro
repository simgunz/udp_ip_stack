#-------------------------------------------------
#
# Project created by QtCreator 2013-10-29T09:35:12
#
#-------------------------------------------------

QT       += core gui network

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

TARGET = UDPBenchmark
TEMPLATE = app


SOURCES += main.cpp\
        udpbenchmark.cpp \
    sleeper.cpp

HEADERS  += udpbenchmark.h \
    sleeper.h

FORMS    += udpbenchmark.ui
