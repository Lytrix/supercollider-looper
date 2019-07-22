/*
@Description: Super Collider OSC Looper Multitrack with i2CEncoderV2
@Date: 2019/05/31
*/

// User Settings ###############################################################

//s.waitForBoot({

(
    Buffer.freeAll;

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

    // SynthDef #####################################################################

    SynthDef(\playbuf, { |amp = 0.5, buf, dur = 1, rate = 1, start = 0, release = 0.01, gate = 1|
        var sig, end, startpos, isForward, frames, env;
        // If release is 1 the buffer won't be modulated until a new buffer starts playing
        isForward = (rate < 0);
        frames = BufFrames.kr(buf);
        startpos = abs((frames * isForward) - (frames * start)) - (2 * isForward);
        sig = PlayBuf.ar(2, buf, BufRateScale.kr(buf) * rate, 1, startpos, loop: 1);
        //sig = sig * EnvGen.kr(Env.new(times: [0.01, dur, release]), gate: 1, doneAction: 2);
        env = EnvGen.kr(Env.adsr(releaseTime:release), gate, doneAction:0);
        // env = EnvGen.kr(Env.perc, gate, doneAction:2);
        sig = sig * env;
        sig = Mix.ar(sig) * amp;
        Out.ar(0, sig);
    }).add;

    ~tracks = ();
    ~amp = ();
    ~start = ();
    ~loop = ();
    ~dur = ();
    ~length = ();
    ~rate = ();

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

    // Loop Functions ################################################################

    ~loops = ();
    ~channels.do { |channel|
        ~loops.put(channel, Synth(\playbuf, [
            \amp: ~amp[channel],
            \buf: ~bufs[channel].at(~tracks[channel]),
            \dur: ~length[channel],
            \rate: ~rate[channel],
            \start: ~start[channel],
            \gate: 0,
            \release: 0.5
        ]));
    };

    ~loopFunction = { |channel|

        ~loops[channel].set(\gate, 1);

        "Playing Channel".scatArgs(channel,
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
            { ~channels.do{ |channel| ~loopFunction.value(channel) }},
            { ~loopFunction.value(channel) }
        )
    };

    ~stopLoop = { |channel|
        if ( channel == nil,
            { ~channels.do { |channel| ~loops.at(channel).set(\gate, 0) }},
            { ~loops.at(channel).set(\gate, 0) }
        );
    };

);
    // OSC Functions ##############################################################
(
    "OSCsender-i2c.scd".loadRelative;

    // Play / Stop
    ~oscPlay = OSCFunc({ ~playLoop.value() }, 'play', NetAddr.localAddr);
    ~oscStop = OSCFunc({ ~stopLoop.value() }, 'stop', NetAddr.localAddr);

    // Mute
    ~oscMute = OSCFunc({ |msg|
        var channel = msg[1];
        var value = msg[2];
        if (value == 0,
            { ~loops[channel].set(\amp, 0); },
            { ~loops[channel].set(\amp, ~amp[channel]); }
        );
        ~mute[channel] = value;
    }, 'mute', NetAddr.localAddr);

    // Random
    ~oscRandom = OSCFunc({ ~stopLoop.value() }, 'random', NetAddr.localAddr);

    // Sample
    ~oscSample.free;
    ~oscSample = OSCFunc({ |msg|
        var channel = msg[1];
        var track = ~tracks[channel] + msg[2];
        if (track > (~bufs[channel].size - 1)) { track = ~bufs[channel].size -1 };
        if (track < 0) { track = 0 };
        ~tracks[channel] = track;
        ("kaka"++channel++"track"++track).postln;
        ~loops[channel].set(\buf, ~bufs[channel].at(track));
    }, 'sample', NetAddr.localAddr);

    // Volume
    ~oscAmp.free;
    ~oscAmp = OSCFunc({ |msg|
        var channel = msg[1];
        var value = ~amp[channel];
        value = value + (msg[2] * (~maxValue[\amp] / ~slices));
        if (value < ~minValue[\amp]) { value = ~minValue[\amp] };
        if (value > ~maxValue[\amp]) { value = ~maxValue[\amp] };
        ~amp[channel] = value;
        ~loops[channel].set(\amp, value);
        ~amp[channel].postln;
    }, 'amp', NetAddr.localAddr);

    // Rate
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
        ~rate[channel].postln;
    }, 'rate', NetAddr.localAddr);

);
//});

// Controllers ################################################################

~playLoop.value(1);
~stopLoop.value();
~loops[1].set(\buf, ~bufs[1].at(4));
~loops[1].set(\rate, -2);
~rate[1] = -1;
~loops[1].get(\amp, { arg value; ("amp is now:" + value).postln; });
~tracks[1].postln;



OSCFunc;

s.boot;
s.plotTree;