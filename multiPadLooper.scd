(
var launchpadOut, padTL, padBL, padTR, padBR, colorBL1, colorBR1, colorTL1, colorTR1, colorBL2, colorBR2, colorTL2, colorTR2, colorON, pads, padMap, madePadList, scales, roots, padOn, padOff, setPadLights, transposes, makePadList, indToNote_, indToNote, midiOut, launchPad, tempoClock, interruptLoopButtons, controlChanInd, tapTempoSetButton, tapTempoToggle, recordButton, lastTap, playMetronome, recordingMetronome, metronomeFunc, preRecordCount, preRecordLength, recordBuffer, color1, tlBanks, trBanks, blBanks, brBanks, banks, bankMap, recordingState, bankSet, bankToSaveTo, bankToRecording, recordColor, tempLoopTask, tempLoopString, createRecordedTask, playingBanks, metronomeFlashTask, recordingInterim, resetRecordingState, interruptLooping, controlChanButton, arrowButtons, color2, up, down, left, right, padsByChannel, recordingStartBeat, recordingEndBeat, truncateLoop, quantize, algOrderList, pythonOSCport, algResponseHandler, algButtons, quantizationLevels, algBanks, liveCodeHandler, algLoopButton, masterClockOSCport, masterClockTempoHandler, onDeckBuffers, algChannelsInfo, recieveBuffer, startChannel;

//MIDIClient.init;
//MIDIIn.connectAll;
launchpadOut = MIDIOut.newByName("Launchpad Pro", "Standalone Port");
launchpadOut.latency = 0;
midiOut = MIDIOut.newByName("IAC Driver", "Bus 2");
midiOut.latency = 0;
pythonOSCport = NetAddr("localhost", 13371);
masterClockOSCport = NetAddr("localhost", 57120);


//OPTIONS
preRecordLength = 0;
truncateLoop = true;
quantizationLevels = [4, 6];


algButtons = [95, 96, 97];
algLoopButton = 98;

a = [1, 2, 3, 4];
b = [5, 6, 7, 8];

pads = Set.new();
padMap = Dictionary.new(); //launchpad-midiNote -> (padInd, channelInd)

makePadList = {|n1, n2, chan|
	var lis = List.new();
	k = 0;
	n1.do({|i| n2.do({|j|
		lis.add((i*10)+j);
		pads.add((i*10)+j);
		padMap.put((i*10)+j, [k, chan]);
		k = k+1;
	})});
	lis
};

algOrderList = List.new();

recordBuffer = List.new(200);

padTL = makePadList.(b, a, 0);
padTR = makePadList.(b, b, 1);
padBL = makePadList.(a, a, 2);
padBR = makePadList.(a, b, 3);
padsByChannel = [padTL, padTR, padBL, padBR];

(pads - padMap.keys()).postln;

colorTL1 = 39;
colorTR1 = 112;
colorBL1 = 4;
colorBR1 = 83;
color1 = [colorTL1, colorTR1, colorBL1, colorBR1];
l = color1;

colorTL2 = 25;
colorTR2 = 45;
colorBL2 = 72;
colorBR2 = 13;
color2 = [colorTL2, colorTR2, colorBL2, colorBR2];

colorON = 13;

tlBanks = [50, 60, 70, 80];
trBanks = [59, 69, 79, 89];
blBanks = [10, 20, 30, 40];
brBanks = [19, 29, 39, 49];
banks = [tlBanks, trBanks, blBanks, brBanks];
k = banks;
bankSet = Set.new();
bankSet.addAll(banks.flatten(1));
//midiNote -> [bankInd, bankChan, isOn, loopTask/nil, loopString, algMelodyTask, algMelodyString]
bankMap = Dictionary.new();
f = bankMap;
(0..3).do({|i| (0..3).do({|j|
	//launchpadOut.control(0, j, color1[i]);
	bankMap.put(banks[i][j], [j, i, false, nil, nil, nil, nil]); //TODO: reverse i,j here and everywhere else
})});
bankSet.do({|i| launchpadOut.control(0, i, 0)});
playingBanks = Set.new();
algBanks = List.new();

//chanInd -> [isOn, task, loopString]
(0..3).do({|i|
	algBanks.add([false, nil, nil]);
});


//define scales and roots
scales = [
	[0, 2, 3, 5, 7, 8, 10], //TL
	[0, 2, 3, 5, 7, 8, 10], //TR
	[0, 2, 3, 5, 7, 8, 10], //BL
	[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], //BR
];
roots = [60, 60, 36, 36];

indToNote_ = {|ind, scale, root, trans|
	root + scale[(ind+trans)%scale.size()] + (((ind+trans) / scale.size).floor * 12);
};

indToNote = {|ind, chan| indToNote_.(ind, scales[chan], roots[chan], transposes[chan])};

transposes = [-1, 4, -12, 0 ]; //+- 4 corresponds to up/down a row, +-1 corresponds to left/right a column
arrowButtons = [91, 92, 93, 94];
up = 91;
down = 92;
right = 93;
left = 94;

interruptLoopButtons = [1, 2, 3, 4];
interruptLooping = [false, false, false, false, false];
launchpadOut.control(0, 1, colorTL1);
launchpadOut.control(0, 2, colorTR1);
launchpadOut.control(0, 3, colorBL1);
launchpadOut.control(0, 4, colorBR1);

controlChanInd = 0;
controlChanButton = 8;
launchpadOut.control(0, controlChanButton, color1[controlChanInd]);

onDeckBuffers = List.fill(16, {nil;});

//[task, midiChanInd]
algChannelsInfo = List.fill(16, {[nil, nil];});


//define setPadLights method
setPadLights = {|padMIDIs, c1, c2, padInd|
	(0..15).do({|i|
		var col;
		if(((i+transposes[padInd]) % scales[padInd].size) == 0, {col = c2}, {col = c1});
		launchpadOut.noteOn(0, padMIDIs[i], col);
	});
};

setPadLights.(padTL, colorTL1, colorTL2, 0);
setPadLights.(padTR, colorTR1, colorTR2, 1);
setPadLights.(padBL, colorBL1, colorBL2, 2);
setPadLights.(padBR, colorBR1, colorBR2, 3);

launchPad = MIDIClient.sources.select({|elem| (elem.name == "Standalone Port")
	&& (elem.device == "Launchpad Pro")})[0];
[launchPad, MIDIClient.sources[2]].postln;
a = {|vel, note, chan, port|
	if(pads.includes(note), {
		var padInfo = padMap[note];
		var newNote = indToNote.(padInfo[0], padInfo[1]);
		midiOut.noteOn(padInfo[1], newNote, vel);
		if(recordingMetronome, {recordBuffer.add([tempoClock.beats, newNote, vel, padInfo[1], "on"])});
	});
};
padOn = MIDIFunc.noteOn(a, nil, nil, launchPad.uid);

b = {|vel, note, chan, port|
	if(pads.includes(note), {
		var padInfo = padMap[note];
		var newNote = indToNote.(padInfo[0], padInfo[1]);
		midiOut.noteOff(padInfo[1], newNote, vel);
		if(recordingMetronome, {recordBuffer.add([tempoClock.beats, newNote, vel, padInfo[1], "off"])});
	});
};
padOff = MIDIFunc.noteOff(b, nil, nil, launchPad.uid);
x = 0;
tempLoopTask = nil; //this var is only not nil when you have a recorded and unsaved loop
tempLoopString = nil;

//TODO: alternative - quantaize to 4ths or 6ths, chose based on minimum error (can change per beat)
//{hit[0] = hit[0].floor + ((hit[0]%1 * 6).round / 6)}
//NOTE - translates hitTime -> duration-before-hit for each beat
quantize = {|oldRecBuf, quantDivArray, startBeat, endBeat|

	//divide array into hits-per-beat
	//apply calc-error-for-hits-and-div
	//select div with least error
	var currentBeat = 0;
	var listsPerBeat = List.new();
	var quantizedHits = List.new();
	var hangingNotes = Set.new();
	var recBuf = List.newFrom(oldRecBuf);
	var timeAfterLastHit;

	listsPerBeat.add(List.new());
	recBuf.do({|hit| [hit[0], startBeat].postln; if(hit[0] < startBeat, {hit[0] = startBeat}) });
	"LOG1".postln;
	recBuf.do({|hit|
		var indexBeat = hit[0].floor-startBeat;
		["HIT", indexBeat, currentBeat, hit].postln;
		if(indexBeat > currentBeat, {
			listsPerBeat.add(List.new());
			currentBeat = indexBeat;
		});
		listsPerBeat[currentBeat].add(hit);
	});
	"POST THAT".postln;

	listsPerBeat.do({|hits|
		var quantLists = List.new();
		var bestList = [List.new(), 1];
		var quantHitList;
		quantDivArray.do({|div|
			var quantList = List.new();
			var error = 0; //TODO: ignore noteOff messages for quantization?
			hits.do({|hit| quantList.add(hit[0].floor + ((hit[0]%1 * div).round / div))});
			(hits.size-1).do({|i| error = error + (hits[i][0] - quantList[i]).abs});
			quantLists.add([quantList, error]);
		});
		quantLists.do({|listErr| if(listErr[1] < bestList[1], {bestList = listErr})});
		quantHitList = List.fill(hits.size, {|i|
			var newHit = List.newFrom(hits[i]);
			newHit[0] = bestList[0][i];
			newHit
		});
		quantizedHits.add(quantHitList);
	});

	//TODO - something still messed up with long held notes
	//TOGGLE QUANTIZATION HERE
	//recBuf = quantizedHits.inject([], _++_);
	recBuf;


	recBuf.do({|elem|
		if(elem[4] == "on",
			{hangingNotes.add(elem[1])},
			{hangingNotes.remove(elem[1])})
	});

	if((hangingNotes.size > 0) || truncateLoop.not,
		{timeAfterLastHit = endBeat - recBuf[recBuf.size-1][0]},
		{timeAfterLastHit = (recBuf[recBuf.size-1][0].ceil - recBuf[recBuf.size-1][0])}
	);

	recBuf.do({|hit| if(true/*hit[4] == "on"*/, {["HIT TIME", hit[4], hit[0]].postln})});

	(recBuf.size-1..1).do({|i| recBuf[i][0] = recBuf[i][0] - recBuf[i-1][0]});
	recBuf[0][0] = recBuf[0][0] - startBeat;

	recBuf.add([timeAfterLastHit, 0, 0, 0, "timeAfterLastHit"]); //xtra vals to simlpify save/load serialization

	"EXIT QUANTIZE".postln;
	recBuf;
	//recBuf.do({|hit| ["Duration TIll", hit[4], hit[0]].postln});
	//["time after last", timeAfterLastHit].postln;
};


createRecordedTask = {|oldRecBuf, isChannelTask=false, channelInd=0|
	var startBeat, timeAfterLastHit, recBuf, newTask, chan;

	recBuf = List.newFrom(oldRecBuf);
	chan = recBuf[0][3];

	newTask = Task({
		var ind = 0;
		var hit;
		var endWait = 0;
		{
			hit = recBuf[ind];
			hit[0].wait;
			if(interruptLooping[chan].not, {
				if(hit[4] == "on", {midiOut.noteOn(hit[3], hit[1], hit[2]);});
				if(hit[4] == "off", {midiOut.noteOff(hit[3], hit[1], hit[2])});
			});
			ind = ind+1;

			if(isChannelTask, {
				if(ind == recBuf.size-2, {
					pythonOSCport.sendMsg("/algRequestUpdate", channelInd);
				});

				if(ind == recBuf.size-1, {
					if(onDeckBuffers[channelInd] != nil, {
						recBuf = onDeckBuffers[channelInd];
						onDechBuffers[channelInd] = nil;
					});
				});
			});

			//TODO: this cuts off notes when loops are superimposed on same instrument
			if(ind == recBuf.size, {midiOut.allNotesOff(recBuf[0][3])});
			ind = ind%recBuf.size;
		}.loop;
	}, tempoClock);

	newTask;
};
r = createRecordedTask;



//TODO: move variable instations to near the functions that use them
f = {|msg, time, addr, recvPort|
	//msg[1] is the new BEAT DURATION (not tempo)
	tempoClock = TempoClock.new(1/msg[1], 0);
	t = tempoClock;
	tempoClock.schedAbs(1, metronomeFunc);
};
OSCFunc(f, "/masterClockBeat").oneShot;
q = {|msg, time, addr, recvPort|
	["MULTILOOP BEAT", tempoClock.beats].postln;
};
OSCFunc(q, "/masterClockBeat");
tapTempoSetButton = 5;
tapTempoToggle = 6;
recordButton = 7;
recordColor = 5;
launchpadOut.control(0, recordButton, recordColor);
lastTap = TempoClock.beats;
playMetronome = false;
recordingMetronome = false;
recordingInterim = false;
preRecordCount = 0;
//0: not recording, 1: "record" hit, 2: bank specified, 3: pre record metronome, 4: actually recording notes
recordingState = 0;
bankToSaveTo = 0;
bankToRecording = Dictionary.new();
c = {|vel, note, chan, port|
	if(interruptLoopButtons.includes(note), {
		var chan = note - interruptLoopButtons[0];
		if((vel == 127), {midiOut.allNotesOff(chan)});
		interruptLooping[chan] = vel == 127;
	});
	if((note == tapTempoSetButton) && (vel == 127), {
		var now = TempoClock.beats;
		if((now - lastTap) < 2, {masterClockOSCport.sendMsg("/uploadTempo", now - lastTap)});
		lastTap = now;
		//TODO - send tap info to master clock
	});
	if((note == tapTempoToggle) && (vel == 127), {playMetronome = playMetronome.not});
	if((note == recordButton) && (vel == 127), {
		//TODO = case statement
		if(recordingState == 0, {
			bankToSaveTo = 0;
			recordingState = 1;
			recordingMetronome = true;
			preRecordCount = 0;
		});
		if(recordingState == 3, {
			tempLoopTask.stop;
			recordBuffer.do({|elem| midiOut.noteOff(elem[3], elem[1])});
			tempLoopTask.free;

			resetRecordingState.();
		});
		if(recordingState == 2, {
			var recBuf;
			recordingState = 3;
			preRecordCount = 0;
			recordingMetronome = false;
			recordingEndBeat = tempoClock.beats.ceil;

			//TODO: handle cases where multiple inst hits in a recBuf, or when there's no noteOns recorded
			chan = recordBuffer[0][3];
			midiOut.allNotesOff(chan);

			recBuf = quantize.(recordBuffer, quantizationLevels, recordingStartBeat, recordingEndBeat);

			tempLoopString = recBuf.collect({|item| item.join(",")}).join("-");
			tempLoopTask = createRecordedTask.(recBuf);
			tempoClock.sched(tempoClock.timeToNextBeat, {tempLoopTask.start; nil;});
		});
	});
	if(bankSet.includes(note) && (vel == 127), {
		var thisBank = bankMap[note];
		if(recordingState == 3,
			{
				//save the recorded buffer to the appropriate bank
				//todo bug: stop and free the existing task in this bank
				if(thisBank[3] != nil, {
					thisBank[3].stop;
					thisBank[3].free;
				});
				thisBank[2] = true;
				thisBank[3] = tempLoopTask;
				thisBank[4] = note + tempLoopString + recordingStartBeat;

				pythonOSCport.sendMsg("/saveLoop",  thisBank[1], thisBank[0],
					roots[thisBank[1]], scales[thisBank[0]].join(","), thisBank[4]);

				playingBanks.add(note);
				resetRecordingState.();
			},
			{
				if(thisBank[3] != nil, {
					//if algsList.size > 0, make OSC call to python alg module
					//args - algsList, inst chanel, bank numner, loopString
					//set recivedAlgTask[chanInd][bankNum] = null
					//if the python func crashes, this remains null and can be checked for
					if(algOrderList.size > 0, {
						pythonOSCport.sendMsg("/algRequest",  thisBank[1], thisBank[0],
							roots[thisBank[1]], scales[thisBank[0]].join(","), thisBank[4])
					});

					tempoClock.sched(tempoClock.timeToNextBeat, {
						if(thisBank[2].not,
							{
								if(false, {//with this as false, banks can be overlayed
								//for all other banks for this inst, stop playing and turn their lights on
								banks[thisBank[1]].do({|bNote|
									if(bankMap[bNote][3] != nil, {
										var elem = bankMap[bNote];
										elem[3].stop;
										elem[2] = false; //TODO: refactor to make bank on/off functions
										Task({0.001.wait; launchpadOut.control(0, bNote, color1[elem[1]]);}).play;
										playingBanks.remove(bNote);
									})
								});});
								midiOut.allNotesOff(thisBank[1]);
								//todo: if algLooping, start algMelodyTask instead (no longer relevant?)
								if(thisBank[5].isNil, {thisBank[3].start}, {thisBank[5].start});
								thisBank[2] = true;
								playingBanks.add(note);
							},
							{
								midiOut.allNotesOff(thisBank[1]);
								"TURNING OFF".postln;
								thisBank[3].stop;
								thisBank[5].stop;
								thisBank[5].free;
								thisBank[5] = nil;
								thisBank[6] = nil;
								thisBank[2] = false;
								launchpadOut.control(0, note, color1[thisBank[1]]);
								playingBanks.remove(note);
						});
						"TEMPOCLOCK FUNC RUN".postln;
						//launchpadOut.control(0, note, 0);
						nil;
					});
				});
		});
	});
	if((note == controlChanButton) && (vel == 127), {
		controlChanInd = (controlChanInd+1) % 4;
		launchpadOut.control(0, controlChanButton, color1[controlChanInd]);
	});
	if(note == algLoopButton, {
		algBanks[controlChanInd][1].stop;
		algBanks[controlChanInd][0] = false;
		midiOut.allNotesOff(controlChanInd); //TODO: clean this up
	});
	if(arrowButtons.includes(note) && (vel == 127), {
		//todo: note off all for that instrument
		var ind = controlChanInd;
		if(note == up, {transposes[ind] = transposes[ind] - 4});
		if(note == down, {transposes[ind] = transposes[ind] + 4});
		if(note == right, {transposes[ind] = transposes[ind] + 1});
		if(note == left, {transposes[ind] = transposes[ind] - 1});
		setPadLights.(padsByChannel[ind], color1[ind], color2[ind], ind);
	});
	//MULTIPLE ALG BUTTONS CAN BE HELD DOWN
	//THEIR ORDER WILL SPECIFY A "pipeline" of transformations
	//if alg button, add/remove from list depending on button up/down
	if(algButtons.includes(note), {
		if(vel == 127,
			{algOrderList.add(note-95)},
			{algOrderList.remove(algOrderList.indexOf(note-95))}
		)
	});
};
MIDIFunc.cc(c, nil, nil, launchPad.uid);

//msg[1] is channel
//msg[2] is bufferString
recieveBuffer = {|msg, time, addr, recvPort|
	var buffer = stringToBuf.(msg[2].asString);
	onDeckBuffers[msg[1].asInt] = buffer;
};
OSCFunc(recieveBuffer, "/algRecieveUpdate");

//msg[1] is channel
//msg[2] is bufferString
startChannel = {|msg, time, addr, recvPort|
	var buffer = stringToBuf.(msg[2].asString);
	var chanInd = msg[1].asInt;
	var channelTask = createRecordedTask(buffer, true, chanInd);
	if(algChannelsInfo[chanInd][0] != nil, {
		algChannelsInfo[chanInd][0].stop;
		algChannelsInfo[chanInd][0].free;
	});
	algChannelsInfo[chanInd][0] = channelTask;
	tempoClock.sched(tempoClock.timeToNextBeat, {channelTask.play; nil;});
};
OSCFunc(startChannel, "/algStart");

//msg[1] is channel
stopChannel = {|msg, time, addr, recvPort|
	var chanInd = msg[1].asInt;
	tempoClock.sched(tempoClock.timeToNextBeat - 0.05, {
		if(algChannelsInfo[chanInd][0] != nil, {
			algChannelsInfo[chanInd][0].stop;
			algChannelsInfo[chanInd][0].free;
			algChannelsInfo[chanInd][0] = nil;
		});
		midiOut.allNotesOff(algChannelsInfo[chanInd][1]);
		nil;
	});
};
OSCFunc(startChannel, "/algStop");

stringToBuf = {|melString|
	melstring.split($-).collect({|hitString|
		var sp = hitString.split($,);
		[sp[0].asFloat, sp[1].asInt, sp[2].asInt, sp[3].asInt, sp[4]]
	});
};

liveCodeHandler = {|msg, time, addr, recvPort|
	var line = msg[1].asString;
	var lineSplit = line.split($ );
	var chanInd = lineSplit[0].asInteger;
	var recBuf = lineSplit[1].split($-).collect({|hitString|
		var sp = hitString.split($,);
		[sp[0].asFloat, sp[1].asInt, sp[2].asInt, sp[3].asInt, sp[4]]
	});
	var algTask;

	//recBuf.sort({|a, b| a[0] < b[0]});
	recBuf.do({|hit| hit.postln});
	algTask = createRecordedTask.(recBuf);
	algBanks[chanInd] = [false, algTask, line];
	tempoClock.sched(tempoClock.timeToNextBeat, {
		algBanks[chanInd][0] = true;
		algBanks[chanInd][1].play;
	});
};
OSCFunc(liveCodeHandler, "/liveCodeEndpoint");

//TODO bug: stop and free task here if it exists
algResponseHandler = {|msg, time, addr, recvPort|
	var line = msg[2].asString;
	var lineSplit = line.split($ );
	var key = lineSplit[0].asInteger;
	var startBeat = lineSplit[2].asFloat;
	var recBuf = lineSplit[1].split($-).collect({|hitString|
		var sp = hitString.split($,);
		[sp[0].asFloat, sp[1].asInt, sp[2].asInt, sp[3].asInt, sp[4]]
	});
	var algTask;
	//recBuf.sort({|a, b| a[0] < b[0]});tempoClock.tempo = 1/(now-lastTap)
	recBuf.do({|hit| hit.postln});

	algTask = createRecordedTask.(recBuf);
	bankMap[key][5] = algTask;
	bankMap[key][6] = line;
	"ALG RESPONSE".postln;
	msg.postln;
};

OSCFunc(algResponseHandler, "/algResponse");

//msg[1] is the new BEAT DURATION (not tempo)
masterClockTempoHandler = {|msg, time, addr, recvPort|
	tempoClock.tempo = 1/msg[1].asFloat;
};
OSCFunc(masterClockTempoHandler, "/masterClockTempo");

/*
python module

class AlgResponder:
- algsList[] - a list of algs that takes a loopString and returns a loopString (default is identity function)
  the elements of this list are what will be replaced with custom functions when live coding
- an oscHandler that applies algslist in order specified by oscAlgsList argument and
  returns the final loop string (along with chanInd and bankNum)


*/
resetRecordingState = {
	recordingMetronome = false;
	recordingState = 0;
	launchpadOut.control(0, recordButton, recordColor);
	recordBuffer.clear();
	tempLoopTask = nil;
	tempLoopString = nil;
};

metronomeFlashTask = Task({
	if(recordingMetronome || (tempLoopTask != nil),
		{launchpadOut.control(0, recordButton, (recordingState==2).if(17,recordColor))});
	playingBanks.do({|bNote| launchpadOut.control(0, bNote, color1[bankMap[bNote][1]])});
	(tempoClock.beatDur/2).wait;
	if(recordingMetronome || (tempLoopTask != nil), {launchpadOut.control(0, recordButton, 0)});
	playingBanks.do({|bNote| launchpadOut.control(0, bNote, 0)});
});

metronomeFunc = {
	metronomeFlashTask.start;
	if(recordingMetronome, {
		if((preRecordCount < preRecordLength),
			{
				recordingInterim = true;
				preRecordCount = preRecordCount + 1;
				["prerecordMetronome", preRecordCount].postln;
			},
			{//TODO: clean up and write comments for recroding state handling
				if(recordingState == 1, {
					recordingState = 2;
					recordingStartBeat = tempoClock.beats.round;
				});
				recordingInterim = false;
				"RECORDING".postln;
			}

		);
	});
	if(playMetronome, {
		if(recordingMetronome,
			{
				Task({ //TODO - refactor duration note on/off stuff into functions
					var drum = recordingInterim.if(37, 38);
					midiOut.noteOn(4, drum, 64); 0.05.wait; midiOut.noteOff(4, drum, 64);}).play;
			},
			{
				Task({midiOut.noteOn(4, 36, 64); 0.05.wait; midiOut.noteOff(4, 36, 64); }).play;
		});
	});
	//["beat", tempoClock.beats, tempoClock.beatDur].postln;
	1;
};


/*
basic layout
   - 4 keyboards, 1 in each quadrant, with 4 melody banks each (color coded on side - buttons)
     where the bank button of a playing bank will be flashing
   - keyboards will have "highlighted" scale roots, and you can "shift" the keyboard up/down/left right
     just like in the quneoSoloKeyboard by using the arrow keys
   - there will be a metronome for keeping the "pulse", and all recorded loops will be an integral
     number of pulses in duration
   - 3 main control buttons (top row) - tap tempo (flashes with metronome), metronome audio on/off,
     recording start/stop, (optionally) "visual play" on/off. "visual play" means that when a clip plays,
     the keyboard layout for that instrument will revert to what it was when the clip was recorded, and
     the "keys" will light up as the note sounds (might not be doable if keyboard is shifted while recording)
   - how to do "interrupt looping"? separate interupt-button for each instrument, held down to "interupt",
     or simply hold down flashing/playing clip to interupt it?
   - what if you want to replay a clip from the start when its already playing
   - saved clip will be launched at start of next complete "pulse", with minor "lateness" in pad hit forgiven
*/

)

// ================================================================================================
// ================================================================================================
//FILE SAVE/LOAD


(
var func = {|a, b=5|
	[a, b].postln;
};
func.(1)
)

(
var file = File("~/joelLoop.txt".standardizePath, "wb");
var lines = List.new();
f.keys.do({|key|
	if(f[key][4] != nil, {
		var str = f[key][4]++"\n";
		lines.add(f[key][4]);
		str.postln;
		//file.putString(str);
	});
});
file.putString(lines.join("\n"));
file.close;
5
)
"5,6,5,3,2,8,5,4,3".split($,)
[ 5, 6, 5, 3, 2, 8, 5, 4, 3 ].join(",")
(
var file = File.open("~/testFilename4.txt".standardizePath, "rb");
var fileStr = file.readAllString;
var fileSplit = fileStr.split($\n);
var launchpadOut = MIDIOut.newByName("Launchpad Pro", "Standalone Port");
fileSplit.size.postln;
fileSplit.do({|line|
	var lineSplit = line.split($ );
	var key = lineSplit[0].asInteger;
	var startBeat = lineSplit[2].asFloat;
	var recBuf = lineSplit[1].split($-).collect({|hitString|
		var sp = hitString.split($,);
		[sp[0].asFloat, sp[1].asInt, sp[2].asInt, sp[3].asInt, sp[4]]
	});
	recBuf.sort({|a, b| a[0] < b[0]});
	recBuf.do({|hit| hit.postln});

	//call createTask (assign to global var) and set it in bankMap (f)
	f[key][3] = r.(recBuf, startBeat);
	f[key][4] = lineSplit[1];

	//turn on lights of necessary banks
	launchpadOut.control(0, k[f[key][1]][f[key][0]], l[f[key][1]]);
});
)


// ================================================================================================
// ================================================================================================
"0.5".asFloat + "7".asInteger
["5", "6", "7"].collect({|st| st.asInt}) + 10

[1, 2, "a"] < [1, 2, "c"]

"abcdefg"[1..3]

Task({}) != nil
(
MIDIClient.init;
var cfunc;
var midiOut = MIDIOut.newByName("IAC Driver", "Bus 1");
midiOut.latency = 0;
a = TempoClock.new(1);
b = TempoClock.new(1);

cfunk = {
	midiOut.(0, 60, 80);
	1;
	b.queue = a.queue
}
)
(
t = Task({ { "I'm loopy".postln; 1.wait;}.loop });
t.start;//TODO: see what results in "already playing" errors (use task.isPlaying)
)
t.play
(
a = 5;
a+=1
)

