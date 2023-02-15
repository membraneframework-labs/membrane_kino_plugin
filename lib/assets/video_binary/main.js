export function init(ctx, payload) {
  console.log("initial data", payload);

  ctx.handleEvent("buffer", ([info, buffer]) => {
    console.log("Buffer received: ", [info, buffer])
  });

  ctx.handleEvent("create", (size) => {
    console.log("Size received: ", size)
  });
}
