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

  console.log("init", info);

  ctx.root.innerHTML = `
    <div class="client">
      <div class="frame-container">
        <video controls autoplay playsinline muted" id="video-player">
        </video>
      </div>
    </div>
  `;

  ctx.handleEvent("create", (info) => {
    console.log("Framerate received: ", info.framerate);

    if (jmuxer !== null) {
      jmuxer.reset();
      jmuxer.destroy();
      jmuxer = null;
    }

    jmuxer = new JMuxer({
      node: 'video-player',
      mode: 'video',
      flushingTime: 1000,
      fps: info.framerate,
      debug: true,
      onError: function (_data) {
        if (/Safari/.test(navigator.userAgent) && /Apple Computer/.test(navigator.vendor)) {
          jmuxer.reset();
        }
      }
    });
  });

  ctx.handleEvent("buffer", ([info, buffer]) => {
    console.log("event: buffer", info, buffer);

    jmuxer.feed({
      video: new Uint8Array(buffer)
    });
  });
}

