/**
* Configuration file for wiring of smartBraceletC module to other common
* components needed for proper functioning
*
*
*/

#include "smartBracelet.h"

configuration smartBraceletAppC {}

implementation {

	components MainC, smartBraceletC as App;
	components RandomC;
	components new AMSenderC(AM_MY_MSG);
	components new AMReceiverC(AM_MY_MSG);
	components ActiveMessageC;
	components new TimerMilliC() as TimerCoupling;
	components new TimerMilliC() as TimerChild;
	//components new FakeSensorC();

	//Boot interface
	App.Boot -> MainC.Boot;

	//Send and Receive interfaces
	App.Receive -> AMReceiverC;
	App.AMSend -> AMSenderC;

	//Radio Control
	App.SplitControl -> ActiveMessageC;

	//Interfaces to access package fields

	App.AMPacket -> AMSenderC;
	App.Packet -> AMSenderC;
	App.PacketAcknowledgements->ActiveMessageC;

	//Timer interface
	App.Timer0 -> TimerCoupling;
	App.Timer1 -> TimerChild;


//Random interface and its initialization	
	App.Random -> RandomC;
	RandomC <- MainC.SoftwareInit;
	//Fake Sensor read
	//App.Read -> FakeSensorC;
}