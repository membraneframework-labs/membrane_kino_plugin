export async function init(ctx, html) {
  await ctx.importCSS("./main.css");

  ctx.root.innerHTML = `
    <div id="clients" class="clients">
      <div class="client">
      <button id="record-button" class="button-base button-gray border-transparent py-2 px-4 inline-flex text-gray-500" data-btn-record="">
        <i class="ri-mic-line text-lg leading-none mr-2" aria-hidden="true"></i>
        <span>Record</span>
      </button>
      </div>
    </div>
  `;

  ctx.root.querySelector("#self-video");

  let recorder = null;
  let recording = false;
  const duration_ms = 1;

  const record_button = ctx.root.querySelector("#record-button");

  async function streamMicrophoneAudio() {
    let stream;
    const constraints = { video: false, audio: true };

    try {
      stream = await navigator.mediaDevices.getUserMedia(constraints);
      const stream_constraints = {
        channelCount: { exact: 1 },
        sampleRate: { exact: 48000 },
        sampleSize: { exact: 16 },
        // noiseSuppression: { exact: false },
      };
      const track = stream.getAudioTracks()[0];
      track.applyConstraints(stream_constraints);

      const capabilities = track.getCapabilities();
      console.log('capabilities', capabilities);
      console.log('constraints', track.getConstraints());

    } catch (error) {
      throw new Error(`
        MediaDevices.getUserMedia() threw an error. 
        Stream did not open.
        ${error.name} - 
        ${error.message}
      `);
    }


    const options = {
      mimeType: 'audio/webm;codecs=opus'
    };
    const recorder = new MediaRecorder(stream, options);

    recorder.addEventListener('dataavailable', async ({ data }) => {
      const result = await data.stream().getReader().read();
      ctx.pushEvent('audio_frame', [{ duration: duration_ms }, result.value.buffer]);
    });

    recorder.start(duration_ms);
    return recorder;
  };

  async function startRecording() {
    record_button.classList.add('recording');
    record_button.querySelector('span').innerText = 'Stop';

    recorder = await streamMicrophoneAudio();
    recording = true;
    ctx.pushEvent('recording_started', {});
  }

  // Function to stop recording
  async function stopRecording() {
    record_button.classList.remove('recording');
    record_button.querySelector('span').innerText = 'Record';

    recorder.stop();
    recording = false;
    ctx.pushEvent('recording_stopped', {});
  }

  record_button.addEventListener('click', async () => {
    if (recording) {
      await stopRecording();
    } else {
      await startRecording();
    }
  });

}

