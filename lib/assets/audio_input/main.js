export async function init(ctx, html) {
  ctx.root.innerHTML = `
    <div id="clients" class="clients">
      <div class="client">
        <button id="record-button">Record</button>
      </div>
    </div>
  `;

  ctx.root.querySelector("#self-video");

  let recorder = null;
  let recording = false;
  const durations_ms = 20;

  const record_button = ctx.root.querySelector("#record-button");

  async function streamMicrophoneAudio() {
    let stream;
    const constraints = { video: false, audio: true };

    try {
      stream = await navigator.mediaDevices.getUserMedia(constraints);
      const stream_constraints = {
        channelCount: { exact: 1 },
        sampleRate: { exact: 48000 },
        // sampleSize: { exact: 1024 },
      };
      stream.getAudioTracks()[0].applyConstraints(stream_constraints);
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
      console.log(result);
      ctx.pushEvent('audio_frame', [{ durations: durations_ms }, result.value.buffer]);
    });

    recorder.start(durations_ms);
    return recorder;
  };

  record_button.addEventListener('click', async () => {
    if (recording) {
      recorder.stop();
      record_button.innerText = 'Record';
      recording = false;
    } else {
      recorder = await streamMicrophoneAudio();
      record_button.innerText = 'Stop';
      recording = true;
    }
  });

}

