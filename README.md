# SuperCollider Sample Looper with i2CEncoders

A version of Roger Pibernat's <a href="https://github.com/loopier/samplematic">Samplemàtic</a> to run with DUPPA's <a href="https://www.tindie.com/products/saimon/i2cencoder-v2-connect-multiple-encoder-on-i2c-bus/">i2CEncoders</a>.


## Prerequisite ##

Stereo Wave files are assumed to be used.
4 folders are required to be this path. Do not put any wavefiles in the root folder.
~samplesPath = "~/Music/Samples/Samplematic"; 
Else you will get errors on evaluating '/' or nil starting the program.
 
The default looper has 5 encoders per channel plus 2 alternative functions:

1. Encoder 1: Sample file index
2. Encoder 2: Volume
3. Encoder 3: Rate
4. Encoder 3: Sample starting point
5. Encoder 4: Sample length
6. Alt Encoder 5: Attack
7. Alt Encoder 5: Pitch

Each channel also has 2 functions triggered by 2 buttons:

1. Send random values
2. Mute channel

The global functions control all channels:

1. Play / Stop switch
2. Send random to all channels
3. Alt switch
4. Pitch
