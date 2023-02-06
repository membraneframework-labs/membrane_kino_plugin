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

  const state = {
    video: {
      width: null,
      height: null
    },
    time_measurements: {
      index: 0,
      start: null,
      delays: []
    }
  };

  ctx.root.innerHTML = `
    <div class="client">
      <div class="frame-container">
      <video style="border: 1px solid #333; max-width: 500px;" controls autoplay poster="images/loader-thumb.jpg" id="video-player"></video>
      </div>
    </div>
  `;

  const videoEl = ctx.root.querySelector("#video-player");

  let jmuxer = null;


  function addClient(clientId) {
    console.log("addClient", clientId);
    // clientsEl.insertAdjacentHTML("beforeend", `
    //   <div class="client" data-client-id="${clientId}">
    //   <p>AddClient "${clientId}"</p>
    //     <div class="frame-container">
    //       <img data-original />
    //     </div>
    //     <div class="frame-container">
    //       <img data-processed />
    //     </div>
    //   </div>
    // `);
  }

  info.clients.forEach(addClient);

  ctx.handleEvent("client_join", ({ client_id }) => {
    console.log("event: client_join", client_id);

    if (client_id !== info.client_id) {
      addClient(client_id);
    }
  });

  ctx.handleEvent("create", (size) => {
    console.log("Size received: ", size);

    jmuxer = new JMuxer({
      node: 'video-player',
      mode: 'video',
      flushingTime: 1000,
      fps: 60,
      debug: true,
      onError: function (data) {
        if (/Safari/.test(navigator.userAgent) && /Apple Computer/.test(navigator.vendor)) {
          jmuxer.reset();
        }
      }
    });

    state.video.width = size.width;
    state.video.height = size.height;
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


    // console.time("rawToBMP");
    // const bmpBuffer = rawToBMP(buffer, state.video.width, state.video.height);
    // console.timeLog("rawToBMP");
    // console.timeEnd("rawToBMP");

    // console.time("src");
    // imgEl.src = bmpBuffer;
    jmuxer.feed({
      video: new Uint8Array(buffer)
    });

    // console.timeLog("src");
    // console.timeEnd("src");

    console.time("buffer_delay");

    state.time_measurements.start = performance.now();

    // console.log("bmpBuffer", bmpBuffer);


    // if (client_id === info.client_id) {

    // } else {
    //   const clientEl = clientsEl.querySelector(`[data-client-id="${client_id}"]`);
    //   clientEl.querySelector("[data-original]").src = DATA_URL_PREFIX + bufferToBase64(originalBuffer);
    //   clientEl.querySelector("[data-processed]").src = DATA_URL_PREFIX + bufferToBase64(processedBuffer);
    // }
  });
}

