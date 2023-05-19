function send_error(err) {
  ctx.pushEvent("error", err);
  console.error(err);
}

function sending_error(fn) {
  return async (...args) => {
    try {
      return fn(...args);
    } catch (err) {
      send_error(err.message);
    }
  }
}

const import_resources = sending_error(async (ctx) => {
  const css = ctx.importCSS("./main.css");
  const icons = ctx.importCSS("https://cdn.jsdelivr.net/npm/remixicon@3.2.0/fonts/remixicon.min.css");
  return Promise.all([css, icons]);
});


export async function init(ctx, info) {
  await import_resources(ctx);

  const duration_ms = info.flush_time
  let recorder = null;
  let recording = false;


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
  const record_button = ctx.root.querySelector("#record-button");


  ctx.handleEvent("create", (info) => {
    console.log("create", info);
  });

  const streamMicrophoneAudio = sending_error(async () => {
    let stream;
    const constraints = { video: false, audio: true };

    try {
      stream = await navigator.mediaDevices.getUserMedia(constraints);
      const track = stream.getAudioTracks()[0];
      const capabilities = track.getCapabilities();
      const stream_constraints = {
        channelCount: { exact: 1 },
        sampleRate: { exact: 48000 },
        sampleSize: { exact: 16 },
      };
      track.applyConstraints(stream_constraints);

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
  });

  const startRecording = sending_error(async () => {
    record_button.classList.add('recording');
    record_button.querySelector('span').innerText = 'Stop';

    recorder = await streamMicrophoneAudio();
    recording = true;
    ctx.pushEvent('recording_started', {});
  });

  const stopRecording = sending_error(async () => {
    record_button.classList.remove('recording');
    record_button.querySelector('span').innerText = 'Record';

    recorder.stop();
    recording = false;
    ctx.pushEvent('recording_stopped', {});
  });

  record_button.addEventListener('click', async () => {
    if (recording) {
      await stopRecording();
    } else {
      await startRecording();
    }
  });

}

