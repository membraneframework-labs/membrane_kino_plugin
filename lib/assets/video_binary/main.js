// import JMuxer from "https://unpkg.com/jmuxer";

export function init_1(ctx, payload) {
  console.log("initial data", payload);

  ctx.handleEvent("buffer", ([info, buffer]) => {
    console.log("Buffer received: ", [info, buffer])
  });

  ctx.handleEvent("create", (size) => {
    console.log("Size received: ", size)
  });
}


export function init(ctx, info) {
  ctx.importCSS("./main.css");
  ctx.importJS("./raw_to_bmp.js");
  ctx.importJS("https://unpkg.com/jmuxer");

  let jmuxer = null;

  const state = {
    time_measurements: {
      index: 0,
      start: null,
      delays: []
    }
  };

  console.log("init", info);

  ctx.root.innerHTML = `
    <div class="client">
      <div class="frame-container">
        <video controls autoplay playsinline" id="video-player">
        </video>
      </div>
    </div>
  `;

  ctx.handleEvent("create", (info) => {
    console.log("Framerate received: ", info.framerate);

    jmuxer = new JMuxer({
      node: 'video-player',
      mode: 'video',
      flushingTime: 1000,
      fps: info.framerate,
      debug: true,
      onError: function (data) {
        if (/Safari/.test(navigator.userAgent) && /Apple Computer/.test(navigator.vendor)) {
          jmuxer.reset();
        }
      }
    });
  });

  ctx.handleEvent("buffer", ([info, buffer]) => {
    console.log("event: buffer", info, buffer);

    console.timeLog("buffer_delay");
    console.timeEnd("buffer_delay");

    state.time_measurements.index++;

    if (state.time_measurements.start !== null) {
      state.time_measurements.delays.push(performance.now() - state.time_measurements.start);
      if (state.time_measurements.index === 300) {
        const delays = state.time_measurements.delays;
        const n = delays.length;
        const mean = delays.reduce((a, b) => a + b) / n
        const std = Math.sqrt(delays.map(x => Math.pow(x - mean, 2)).reduce((a, b) => a + b) / n)

        console.log("delays mean {} std {}", mean, std);
      }
    }

    jmuxer.feed({
      video: new Uint8Array(buffer)
    });

    console.time("buffer_delay");

    state.time_measurements.start = performance.now();
  });
}

