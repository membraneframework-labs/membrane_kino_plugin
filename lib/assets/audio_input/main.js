export async function init(ctx, html) {
  ctx.root.innerHTML = `
    <div id="clients" class="clients">
      <div class="client">
        <button id="record-button">Record</button>
        <audio id="audio-player" controls></audio>
      </div>
    </div>
  `;

  ctx.root.querySelector("#self-video");

  let recorder = null;
  let recording = false;

  const record_button = ctx.root.querySelector("#record-button");
  const audio_player = ctx.root.querySelector("#audio-player");

  async function streamMicrophoneAudio() {
    let stream;
    const constraints = { video: false, audio: true };

    try {
      stream = await navigator.mediaDevices.getUserMedia(constraints);
    } catch (error) {
      throw new Error(`
        MediaDevices.getUserMedia() threw an error. 
        Stream did not open.
        ${error.name} - 
        ${error.message}
      `);
    }

    const recorder = new MediaRecorder(stream);

    recorder.addEventListener('dataavailable', ({ data }) => {
      console.log(data);
    });

    recorder.start(40);
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

