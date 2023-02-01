export function init(ctx, payload) {
  ctx.importJS("https://unpkg.com/yuv-canvas@1.2.11");

  console.log("initial data", payload);

  ctx.handleEvent("buffer", ([info, buffer]) => {
    console.log("Buffer received: ", [info, buffer])
  });

  ctx.handleEvent("create", (size) => {
    console.log("Size received: ", size)
  });
}
