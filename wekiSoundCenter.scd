//Simple Weki Sampler

NetAddr.langPort

//load the synthdefs

(

SynthDef.new(\master, {|inbus, outbus, amp = 1|

	var sig;
	sig = In.ar(inbus, 1);
	sig = (sig * amp)!2;
	Out.ar(0, sig);

}).send(s);

SynthDef.new(\simplePlayerMono, {|bufNum, loop = 0, trig = 1, rate = 1, pos = 0, amp = 0, outbus = 0|

	var sig;

	sig = PlayBuf.ar(1, bufNum, rate: rate, startPos: pos * BufFrames.kr(bufNum), loop: loop);
	sig = Pan2.ar(sig , 0) * amp;
	sig = sig * EnvGen.kr(Env.asr(0.01,1,0.2),trig,doneAction:2);
	Out.ar(outbus, sig);
}).send(s);

SynthDef.new(\pitchPlayerMono, {|bufNum, loop = 0, trig = 1, rate = 1, pos = 0, amp = 0, outbus = 0|

	var sig;

	sig = PlayBuf.ar(1, bufNum, rate: rate, startPos: pos * BufFrames.kr(bufNum), loop: loop);
	sig = PitchShift.ar(sig, windowSize: 0.2, pitchRatio: 1/rate, timeDispersion: 0.01);

	sig = Pan2.ar(sig , 0) * amp;
	sig = sig * EnvGen.kr(Env.asr(0.01,1,0.2),trig,doneAction:2);
	Out.ar(outbus, sig);
}).send(s);


SynthDef.new(\simplePlayerStereo, {|bufNum, amp = 0, loop = 0, trig = 1, rate = 1, pos = 0, outbus=0|

	var sig;

	sig = PlayBuf.ar(2, bufNum, rate: rate, startPos: pos * BufFrames.kr(bufNum), loop: loop);
	sig = Pan2.ar(sig , 0) * amp;
	sig = sig * EnvGen.kr(Env.asr(0.01,1,0.2),trig,doneAction:2);
	Out.ar(outbus, sig);

}).send(s);

)



//TODO

// tempo clock
// looping ?

//load a basic gui
(


//gui
var w,

fv = Array.newClear(2),
gv = Array.newClear(2),
mc,


addSample = Array.newClear(2),
sampleSelector = Array.newClear(2),
delButt = Array.newClear(2),
selSamplesBut = Array.newClear(2),
clearAll = Array.newClear(2),
playSample = Array.newClear(2),
selSamplesList = Array.newClear(2),

//data
selSamples = Array.newClear(2), selRates = Array.newClear(2),
currentSample = [0,0],
isMet,

//functions
loadSample,  calcSampleRatesFunc,
selSamplesFunc,  selRateFunc, startMetronomeFunc;


//beats variables
var avPhraseLength = 4, numPhrases = [8,5],
loopSynths = Array.newClear(2),
metronome, currBeat, tempoSlide, port, rateMod = 1, numTrigs = [0,0], newPhrase = [0,0], phraseThresh = 0;


loopSynths.size().do{|count| loopSynths[count] = Array.newClear(8)};

port = NetAddr.new("192.168.0.1", 8000);    // create the NetAddr

~tempoClock = TempoClock.new;




w = Window("simpleSamplePlayer", Rect(0, 0, 640, 1000)).front;

fv[0] = FlowView.new(w, Rect(0,0,320,480));
gv[0] = FlowView.new(w, Rect(320,0,320,480));

fv[1] = FlowView.new(w, Rect(0,340,320,480));
gv[1] = FlowView.new(w, Rect(320,340,320,480));

mc = FlowView.new(w, Rect(0,700,640,100));

~sampleArray = Array.newClear(2);
~sampleArray.do{|item| item = Array.newClear()};


loadSample = {|player|
	Dialog.openPanel({ arg path;

		loopSynths[player].do{|item|
			item.set(\trig, 0);
		};

		selSamples[player] = Array.newClear();

		avPhraseLength = 0;

		selSamplesList[player].items = Array.new();
		selSamples[player] = Array.new();
		selRates = Array.newClear(4);

		path.size().do{|i|
			var item, label;

			item = path[i];
			label = path[i];
			label = label.split;
			label = label[label.size()-1].asSymbol;
			sampleSelector[player].addItem(label);

			{

				~sampleArray[player] = ~sampleArray[player].add(
					Buffer.read(s, item);
				);

				s.sync;

				("loaded " ++ item ++ "... ").postln;

			}.fork;


			currentSample[player] = 0;

		};

		calcSampleRatesFunc.value;

		},{
			"cancelled".postln;
	},true);
};


startMetronomeFunc = {

	//"startMetronome".postln;
	metronome.stop;
	metronome = Task({

		currBeat = -1;

		loop{
			currBeat = (currBeat + 1)%16;
			("beat" ++ currBeat).postln;
			if(isMet == true, {x = {SinOsc.ar(1000,0, EnvGen.kr(Env.perc(0.01,0.05), doneAction:2)) * 0.1}.play});
			port.sendMsg("/beat", currBeat);

			if(currBeat == 0){

				//"sync".postln;

				2.do{|player|
					~tempoClock.schedAbs(0, {

						selSamples[player].size().do{|count|
							var amp = 0;

							if(currentSample[player] == count){amp = 0.5};

							loopSynths[player][count].set(\trig,0);

							if(player == 0, {
								loopSynths[player][count] = Synth.new(\simplePlayerMono, [
									\bufNum, selSamples[player][count],
									\loop, 1, \rate, selRates[player][count], \pos, 0, \amp, amp
								]);
							},{
								loopSynths[player][count] = Synth.new(\pitchPlayerMono, [
									\bufNum, selSamples[player][count],
									\loop, 1, \rate, selRates[player][count], \pos, 0, \amp, amp
								]);

							});
						};
						nil;
					});
				}

			};


			1.wait;
		}

	}).play(~tempoClock);
};

calcSampleRatesFunc = {

	{
		var numItems = 0;
		2.wait;

		2.do{|player|
			~sampleArray[player].do{|item|
				avPhraseLength = avPhraseLength + item.numFrames;
				numItems = numItems + 1;
			};
		};

		avPhraseLength = avPhraseLength/numItems;
		~tempoClock.tempo = 1/(avPhraseLength/(44100*16));

	}.fork;

};


selSamplesFunc = {|player|

	var sel, isValid, indexes;

	loopSynths[player].size().do{|count|
		loopSynths[player][count].set(\trig, 0);
	};

	selSamplesList[player].items = Array.new();
	if(~sampleArray[player].size() >= numPhrases[player]){

		selSamples[player] = Array.new();
		selRates[player] = Array.newClear(numPhrases[player]);


		numPhrases[player].do{


			isValid = false;

			while({isValid == false}){
				var label;
				sel = ~sampleArray[player].choose;
				if(selSamples[player].includes(sel) == false){
					selSamples[player] = selSamples[player].add(sel);
					label = sel.path;
					label = label.split;
					label = label[label.size()-1].asSymbol;
					selSamplesList[player].addItem(label);
					isValid = true;

				}
			}
		};


		selRateFunc.value(player);

		currBeat = -1; // will retrigger the new samples





	};

	nil;

};


selRateFunc = {|player|

	numPhrases[player].do{|count|
		var rate;

		rate = selSamples[player][count].numFrames/avPhraseLength * rateMod;
		if(rate > 1.3,{
			rate = rate/2;
		});

		if(rate < 0.5, {
			rate = rate * 2;
		});


		selRates[player][count] = rate; // * 2;

	};

	selRates[player].postln;


};

startMetronomeFunc.value();


2.do{|player|

	sampleSelector[player] = EZListView.new(fv[player],200@230, " List:",

		globalAction: { |a| currentSample[player] = a.value }

	)
	.setColors(Color.grey, Color.white);

	fv[player].startRow;

	addSample[player] = ActionButton(fv[player],"add sample",{loadSample.value(player)} ,minWidth: 100, minHeight: 40);


	selSamplesList[player] = EZListView.new(gv[player],200@230, " SelSamples:").setColors(Color.grey, Color.white);
	selSamplesBut[player] = ActionButton(gv[player],"sel samples",{

		currentSample[player] = 0;
		selSamplesFunc.value(player);
		}

		,minWidth: 100, minHeight: 40);


	delButt[player] = ActionButton(fv[player],"delete from bank",{
		~sampleArray[player][currentSample[player]].free;
		~sampleArray[player].removeAt(currentSample[player]);
		sampleSelector[player].removeItemAt(currentSample[player]);
		sampleSelector[player].valueAction = 0;
	},minWidth: 100, minHeight: 40);

	clearAll = ActionButton(fv[player],"clear all samples",{

		loopSynths[player].size().do{|count|
			loopSynths[player][count].set(\trig, 0);
		};

		//metronome.stop;

		"clear all samples".postln;
		~sampleArray[player].size().do{|c|
			~sampleArray[player][c].free;
			sampleSelector[player].removeItemAt(0);
		};

	},minWidth: 100, minHeight: 40);

	playSample[player] = ActionButton(fv[player],"play Sample",{

		if(~sampleArray[player].size() > 0, {
			x = Synth.new(\pitchPlayerMono, [\bufNum, ~sampleArray[player][currentSample[player]]]);
		});
	},minWidth: 100, minHeight: 40);



	numPhrases[player].do{|count|

		var lbl = "play " ++ (count + 1);

		ActionButton(gv[player], lbl,{
			var pos;
			currentSample[player] = count;
			if(selSamples[player].size() > 0){
				numPhrases[player].do{|ct|
					if(ct != count,{loopSynths[player][ct].set(\amp, 0)});
				};
				loopSynths[player][count].set(\amp, 0.5);
			}
		}, minWidth: 50, minHeight: 30);


	};


};

tempoSlide = Slider(mc, Rect(20, 100, 100, 20))
.action_({
	//(tempoSlide.value + 0.5).postln;
	rateMod = (tempoSlide.value + 0.5);
	~tempoClock.tempo = 1/(avPhraseLength/(44100*16))* rateMod;

	2.do{|player|
		selRateFunc.value(player);
		selRates[player].size().do{|count|
			loopSynths[player][count].set(\rate, selRates[player][count]);
		};
	};

}).background_(Color.rand)
.value = 0.5;

ToggleButton(mc, "metronome",{ isMet = true; },{ isMet = false; });

w.onClose = {

	2.do{|player|

		~sampleArray[player].size().do{|c|
			~sampleArray[player][c].free;
		};

		loopSynths[player].size().do{|count|
			loopSynths[player][count].set(\trig,0);
		};

	};

	metronome.stop;
	OSCdef(\param).clear;
};

//the OSC node


OSCdef(\param, {|msg|



	var index = msg[1], sIndex;
	msg.postln;

	if(index == 0, {
		sIndex = msg[2];
		},
		{
			sIndex = floor(min(numPhrases[index], max(0, msg[2] * (numPhrases[index] + 1))))
		}
	);


	if(index < 2){

		//if(currentSample[index] != sIndex, {

			//msg.postln;
			sIndex.postln;
			if(sIndex == newPhrase[index],{
				numTrigs[index] = numTrigs[index] + 1;
				numTrigs[index].postln;
				},{
				newPhrase[index] = sIndex;
			});


			if(numTrigs[index] > phraseThresh){

				currentSample[index] = sIndex;

				if(sIndex == 0,

					{
						numPhrases[index].do{|ct|
							loopSynths[index][ct].set(\amp, 0);
						};

						//uncomment for changing samples with weki
						//AppClock.sched(0,selSamplesFunc);
						//

					}, {

						if(selSamples[index].size() > 0){
							numPhrases[index].do{|ct|
								if(ct != (sIndex - 1),{loopSynths[index][ct].set(\amp, 0)});
							};
							loopSynths[index][sIndex - 1].set(\amp, 0.5);
						}

					}

				);

			};

		//});

	};


}, '/OSCSynth/params');

)











