print "********************************************";
print "*                                          *";
print "*             TOSSIM Script                *";
print "*                                          *";
print "********************************************";

import sys;
import time;

import sys;
import time;

from TOSSIM import *;

t = Tossim([]);

sf = SerialForwarder(9001);
throttle = Throttle(t, 10);
sf_process=True;
sf_throttle=True;

topofile="topology.txt";
modelfile="meyer-heavy.txt";


print "Initializing mac....";
mac = t.mac();
print "Initializing radio channels....";
radio=t.radio();
print "    using topology file:",topofile;
print "    using noise file:",modelfile;
print "Initializing simulator....";
t.init();


simulation_outfile = "simulation.txt";
print "Saving sensors simulation output to:", simulation_outfile;
simulation_out = open(simulation_outfile, "w");

out_file = open(simulation_outfile, "w");
out_terminal = sys.stdout;

#Add debug channel
print "Activate debug message on channel init"
t.addChannel("init",out_file);
t.addChannel("init",out_terminal);
print "Activate debug message on channel boot"
t.addChannel("boot",out_file);
t.addChannel("boot",out_terminal);
print "Activate debug message on channel radio"
t.addChannel("radio",out_file);
t.addChannel("radio",out_terminal);
print "Activate debug message on channel radio_send"
t.addChannel("radio_send",out_file);
t.addChannel("radio_send",out_terminal);
print "Activate debug message on channel radio_ack"
t.addChannel("radio_ack",out_file);
t.addChannel("radio_ack",out_terminal);
print "Activate debug message on channel radio_rec"
t.addChannel("radio_rec",out_file);
t.addChannel("radio_rec",out_terminal);
print "Activate debug message on channel radio_pack"
t.addChannel("radio_pack",out_file);
t.addChannel("radio_pack",out_terminal);
print "Activate debug message on channel role"
t.addChannel("role",out_file);
t.addChannel("role",out_terminal);


print "Creating node 1...";
node1 =t.getNode(1);
time1 = 0*t.ticksPerSecond();
node1.bootAtTime(time1);
print ">>>Will boot at time",  time1/t.ticksPerSecond(), "[sec]";

print "Creating node 2...";
node2 = t.getNode(2);
time2 = 0*t.ticksPerSecond();
node2.bootAtTime(time2);
print ">>>Will boot at time", time2/t.ticksPerSecond(), "[sec]";

print "Creating node 3...";
node3 = t.getNode(3);
time3 = 0*t.ticksPerSecond();
node3.bootAtTime(time3);
print ">>>Will boot at time", time3/t.ticksPerSecond(), "[sec]";

print "Creating node 4...";
node4 = t.getNode(4);
time4 = 0*t.ticksPerSecond();
node4.bootAtTime(time4);
print ">>>Will boot at time", time4/t.ticksPerSecond(), "[sec]";



print "Creating radio channels..."
f = open(topofile, "r");
lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print ">>>Setting radio channel from node ", s[0], " to node ", s[1], " with gain ", s[2], " dBm"
    radio.add(int(s[0]), int(s[1]), float(s[2]))


#Creazione del modello di canale
print "Initializing Closest Pattern Matching (CPM)...";
noise = open(modelfile, "r")
lines = noise.readlines()
compl = 0;
mid_compl = 0;

print "Reading noise model data file:", modelfile;
print "Loading:",
for line in lines:
    str = line.strip()
    if (str != "") and ( compl < 10000 ):
        val = int(str)
        mid_compl = mid_compl + 1;
        if ( mid_compl > 5000 ):
            compl = compl + mid_compl;
            mid_compl = 0;
            sys.stdout.write ("#")
            sys.stdout.flush()
        for i in range(1, 5):
            t.getNode(i).addNoiseTraceReading(val)
print "Done!";

for i in range(1, 5):
    print ">>>Creating noise model for node:",i;
    t.getNode(i).createNoiseModel()


print "Start simulation with TOSSIM! \n\n\n";

if ( sf_process == True ):
  sf.process();
if ( sf_throttle == True ):
  throttle.initialize();


for i in range(0,5000):
	t.runNextEvent()
	if ( sf_throttle == True ):
  		throttle.checkThrottle();
  	if ( sf_process == True ):
  		sf.process()
	if (i == 3000):
		node4.turnOff();
	
print "\n\n\nSimulation finished!";
