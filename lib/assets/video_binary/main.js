export function init(ctx, info) {
  ctx.importCSS("./main.css");
  ctx.importJS("./raw_to_bmp.js");
  ctx.importJS("https://unpkg.com/jmuxer");

  let jmuxer = null;

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
      jmuxer.clearBuffer();
    } else {
      const videoEl = ctx.root.querySelector("#video-player");
      console.log("Video element: ", videoEl.controlsList);
      jmuxer = new JMuxer({
        node: 'video-player',
        mode: 'video',
        flushingTime: 1000,
        fps: info.framerate,
        debug: false,
        onError: function (_data) {
          if (/Safari/.test(navigator.userAgent) && /Apple Computer/.test(navigator.vendor)) {
            jmuxer.reset();
          }
        }
      });
    }
  });

  ctx.handleEvent("buffer", ([info, buffer]) => {
    jmuxer.feed({
      video: new Uint8Array(buffer)
    });
  });
}

