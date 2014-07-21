
   // send the application the message "hello" with the para

(

var lbeat = 0;
~tc = TempoClock.new;

OSCdef(\beat).clear;
OSCdef(\beat, {|msg, time|

	var diff, fac = 1;
	diff = time-lbeat;
	lbeat = time;
	diff.post; " , ".post;
	~tc.timeToNextBeat.postln;


	if(~tc.timeToNextBeat < 0.95   ,{
		if( ~tc.timeToNextBeat > 0.05){
			"ahead".postln; fac = max(~tc.timeToNextBeat, 0.8)}});

	~tc.tempo = (1.0/diff) * fac;


}, '/beat');

t = Task.new({

	loop{
		play{SinOsc.ar(440,0,0.2) * EnvGen.kr(Env.perc, doneAction:2)};
		1.wait;
	};

}).start(~tc);



)

~tc2.tempo = 3.0

(

~tc2 = TempoClock.new(2);
b = NetAddr.new("127.0.0.1", 57120);    // create the NetAddr

f = Task.new({

	loop{
		var count = 0;
		count = count%16;
		play{WhiteNoise.ar * EnvGen.kr(Env.perc(0.001,0.05), doneAction:2)};

		b.sendMsg("/beat", count);
		1.wait;
	};

}).start(~tc2);

)



