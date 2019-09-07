/*
* @Description: Super Collider OSC Looper Multitrack with i2CEncoderV2
* @Date: 2019/05/31
*/

// User Settings ###############################################################

(

s.waitForBoot({

    //Buffer.freeAll;

    ~slices = 16;
    ~channels = 4;
    ~samplesPath = "~/Music/Samples/Samplematic/";
    ~encoders = ["Sample", "Amp", "Rate", "Start", "Length"];
    ~minValue = ();
    ~minValue.putAll(Dictionary[\amp -> 0,   \rate -> -2.0, \start -> 0]);
    ~maxValue = ();
    ~maxValue.putAll(Dictionary[\amp -> 1.0, \rate -> 2.0,  \start -> 1.0]);

    // Load Buffers ################################################################

    ~duration = ();

    ~loadBufSubfolders = { |path|
        var bufs = ();
        "Hi, we'll play tracks from".scatArgs(path).postln;
        PathName(path).entries.do{ |subdir, i|
            var msg;
            if(i < ~channels) {
                bufs.put(
                    i,
                    Array.fill(subdir.entries.size, { |x|
                        Buffer.read(s, subdir.entries.at(x).fullPath);
                    });
                );
                ~duration.put(
                    i, Array.fill(subdir.entries.size, { |x|
                        SoundFile.openRead(subdir.entries.at(x).fullPath).duration;
                    })
                );
                subdir.pathOnly.scatArgs(">",subdir.entries.size, "tracks").postln;
            };
        };
        bufs;
    };

    ~bufs = ~loadBufSubfolders.value(~samplesPath.standardizePath);

    s.sync; // wait for buffers to be loaded

    // SynthDef #####################################################################

    SynthDef(\playbuf, { |amp = 0.5, buf, dur = 1, rate = 1, start = 0, release = 0.01, gate = 1, tempo = 1, mute = 1, pitch = 1|
        var sig, end, startpos, isForward, frames, env, clock;
        // If release is 1 the buffer won't be modulated until a new buffer starts playing
        isForward = (rate < 0);
        frames = BufFrames.kr(buf);
        //startpos = frames * start;
        startpos = abs( (frames * isForward) - (frames * start) ) - (2 * isForward);
        clock = Impulse.kr(1 / (BufDur.kr(buf) * dur));
        //("startpos"++startpos).postln;
        sig = PlayBuf.ar(2, buf, BufRateScale.kr(buf) * rate, trigger:clock, startPos:startpos, loop:0);
        env = EnvGen.kr(Env.adsr(releaseTime:release), gate, doneAction:0);
        sig = sig * env;
        sig = Mix.ar(sig) * amp * mute;
        sig = PitchShift.ar(sig, pitchRatio:pitch);
        //start.poll;
        Out.ar(0, sig);
    }).add;

    s.sync; // Fix *** ERROR: SynthDef playbuf not found FAILURE IN SERVER /s_new SynthDef not found

    // Loop Functions ##################################################################

    ~tracks = ();
    ~amp = ();
    ~start = ();
    ~loop = ();
    ~dur = ();
    ~length = ();
    ~rate = ();
    ~pitch = ();
    ~pitch = Array.fill(~channels, 1);
    ~mute = Array.fill(~channels, 1);

    ~initAll = {
        ~channels.do{ |channel|
            var start_seconds;
            // Tracks
            ~tracks.put(channel, rrand(0, (~bufs[channel].size - 1)));
            // Amp
            ~amp[channel] = 0.5;
            // Rate
            ~rate_steps = 128;
            ~rate_range = ~minValue[\rate].abs + ~maxValue[\rate];
            ~rate[channel] = ~maxValue[\rate].rand2;
            // Start
            ~start.put(channel, (rrand(0.0, (1.0 - (1 / ~slices))) * ~slices).round / ~slices);
            // Duration
            ~dur.put(channel, ~duration[channel].at(~tracks[channel]));
            ~length[channel] = ~dur[channel];
            ~length.put(channel, rrand((~dur[channel] / ~slices), ~dur[channel]));
            start_seconds = ~length[channel] * ~start[channel];
            if ((start_seconds + ~length[channel]) > ~dur[channel]) {
                ~length[channel] = ~dur[channel] - start_seconds;
            }
        }
    };

    ~initAll.value();

    ~loops = ();
    ~channels.do { |channel|
        ~loops.put(channel, Synth(\playbuf, [
            \amp: ~amp[channel],
            \buf: ~bufs[channel].at(~tracks[channel]),
            \dur: ~length[channel],
            \gate: 0,
            \mute: ~mute[channel],
            \pitch: 1,
            \rate: ~rate[channel],
            \release: 0.5,
            \start: ~start[channel]
        ]));
    };

    ~loopFunction = { |channel|
        ~loops[channel].set(\gate, 1);

        "*".scatArgs(channel,
            "> Track", ~tracks[channel],
            ">", ~bufs[channel].at(~tracks[channel]).path.replace(~samplesPath.standardizePath)
        ).postln;
        "\t".scatArgs(
            "Start:", ~start[channel],
            "Length:",~length[channel].round(1e-2),
            "Duration:", ~dur[channel].round(1e-2),
            "Rate:", ~rate[channel].round(1e-2)
        ).postln;
    };

    ~playLoop = { |channel|
        if ( channel == nil,
            { ~channels.do{ |channel| ~loopFunction.value(channel); }},
            { ~loopFunction.value(channel) }
        )
    };

    ~stopLoop = { |channel|
        if ( channel == nil,
            { ~channels.do { |channel| ~loops.at(channel).set(\gate, 0) }},
            { ~loops.at(channel).set(\gate, 0) }
        );
    };

    // OSC Functions ##############################################################

    "OSCsender-i2c.scd".loadRelative;

    // Global 1. Play / Stop
	n = NetAddr("192.168.8.100", 57120); // 57120 is sclang default port
	//n = NetAddr.localAddr;

    ~oscPlay = OSCFunc({ ~playLoop.value(); }, 'play');
    ~oscStop = OSCFunc({ ~stopLoop.value() }, 'stop');

    // Global 2. Random
    ~oscRandom = OSCFunc({ ~stopLoop.value() }, 'random');

    // Global 3. Pitch
    ~oscPitch = OSCFunc({ |msg|
        var ch = msg[1];
        var value = msg[2];
        if ( ch == -1,
            { ~channels.do { |channel|
                ~pitch[channel] = ~pitch[channel] + (value / 1000);
                ~loops.at(channel).set(\pitch, ~pitch[channel]);
                value.postln;
                ("/pitch " ++ ~pitch[channel]).postln;
            }},
            {
                ~pitch[ch] = ~pitch[ch] + (value / 1000);
                ~loops.at(ch).set(\pitch, ~pitch[ch]);
            }
        );
    }, 'pitch');

    // Channel 1. Sample
    ~oscSample.free;
    ~oscSample = OSCFunc({ |msg|
        var channel = msg[1];
        var track = ~tracks[channel] + msg[2];
        if (track > (~bufs[channel].size - 1)) { track = ~bufs[channel].size -1 };
        if (track < 0) { track = 0 };
        ~tracks[channel] = track;
        ~dur[channel] = ~duration[channel].at(track);
        ~loops[channel].set(\buf, ~bufs[channel].at(track));
    }, 'switch');

    // 2. Volume
    ~oscAmp.free;
    ~oscAmp = OSCFunc({ |msg|
        var channel = msg[1];
        var value = ~amp[channel];
        value = value + (msg[2] * (~maxValue[\amp] / ~slices));
        if (value < ~minValue[\amp]) { value = ~minValue[\amp] };
        if (value > ~maxValue[\amp]) { value = ~maxValue[\amp] };
        ~amp[channel] = value;
        ~loops[channel].set(\amp, value);
        ("Volume" ++ ~amp[channel]).postln;
    }, '/amp');

    // 3. Rate
    ~oscRate.free;
    ~oscRate = OSCFunc({ |msg|
        var channel = msg[1];
        var value = ~rate[channel];
        value = value + (msg[2] * (~rate_range / ~rate_steps));
        if (value < ~minValue[\rate]) { value = ~minValue[\rate] };
        if (value > ~maxValue[\rate]) { value = ~maxValue[\rate] };
        if (value == 0) {
            if (msg[2].isPositive,
                { value = ~rate_range / ~rate_steps },
                { value = (~rate_range / ~rate_steps).neg }
            )
        };
        ~rate[channel] = value;
        ~loops[channel].set(\rate, value);
        ("Rate" ++ ~rate[channel]).postln;
        ("Dur" ++ ~dur[channel]).postln;
    }, 'rate');


    // 4. Start
    ~oscStart.free;
    ~oscStart = OSCFunc({ |msg|
        var channel = msg[1];
        var value = ~start[channel] + (msg[2] / ~slices);
        if (value < ~minValue[\start]) { value = ~minValue[\start] };
        if (value >= ~maxValue[\start]) { value = ~maxValue[\start] - (1 / ~slices) };
        ~start[channel] = value;
        ~loops[channel].set(\start, value);
        ("start" ++  value).postln;
    }, 'start');

    // 5. Length
    ~oscLength.free;
    ~oscLength = OSCFunc({ |msg|
        var channel = msg[1];
        var value = ~length[channel] + (msg[2] / ~slices);
        if (~start[channel] + value > ~maxValue[\start]) {
            value = 1 - ~start[channel];
        };
        if (value < (1 / ~slices)) { value = 1 / ~slices };
        ~length[channel] = value;
        ~loops[channel].set(\dur, value);
        ("length" ++  value).postln;
    }, 'dur');

    // 6. Mute
    ~oscMute = OSCFunc({ |msg|
        var channel = msg[1];
        var value = msg[2];
        ~loops[channel].set(\mute, value);
        ~mute[channel] = value;
    }, 'mute');

});

);

// Controllers ################################################################

~playLoop.value(0);
~stopLoop.value(0);
~loops[1].set(\buf, ~bufs[1].at(4));
~loops[1].set(\rate, -2);
~rate[1] = -1;
~loops[0].get(\amp, { arg value; ("amp is now:" + value).postln; });
~tracks[1].postln;
~setparam = {|loop, paramname, paramvalue|
    ~loops[loops].set(paramname, paramvalue);
};

~loops[3].set(\pitch, 0.971);

s.boot;
s.plotTree;