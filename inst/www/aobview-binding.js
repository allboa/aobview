// Shiny output binding for aobview's aobviewOutput() and renderAobview()
// (allboa/design decision 0009). Each render value is
//   {scene: <scene JSON text>, blobs: {key: <base64>}, theme, select: [ids],
//    serial: <render count>}
// and is drawn with the renderer's aob.render() into the output element.
// The renderer talks protocol 1 (decision 0007) over a channel made here
// instead of a websocket: the page's hello is answered here with R's hello
// (the selectable layers and the serial from the render value), and each
// select and view message becomes a Shiny input value,
// input$<outputId>_aob_select and input$<outputId>_aob_view.
(function () {
  "use strict";
  if (typeof window === "undefined" || !window.Shiny || !window.aob) return;

  function channelFor(el, x) {
    return function (onState) {
      var listeners = [];
      var open = true;
      // "open" must not be reported while the channel is being made.
      setTimeout(function () {
        if (open) onState("open", {});
      }, 0);
      return {
        get connected() {
          return open;
        },
        send: function (m) {
          if (!open) return false;
          var msg = typeof m === "string" ? JSON.parse(m) : m;
          if (msg.type === "hello") {
            var hello = { type: "hello", protocol: 1, scene: x.serial, select: x.select || [],
                          max_message: 16777216 };
            setTimeout(function () {
              if (open) listeners.slice().forEach(function (f) { f(hello); });
            }, 0);
          } else if (msg.type === "select" || msg.type === "view") {
            window.Shiny.setInputValue(el.id + "_aob_" + msg.type, msg, { priority: "event" });
          }
          return true;
        },
        onMessage: function (f) {
          listeners.push(f);
          return function () {
            var i = listeners.indexOf(f);
            if (i >= 0) listeners.splice(i, 1);
          };
        },
        close: function () {
          open = false;
        },
      };
    };
  }

  var binding = new window.Shiny.OutputBinding();
  binding.find = function (scope) {
    return window.jQuery(scope).find(".aobview-output");
  };
  binding.renderValue = function (el, x) {
    // Each render has a token: a render that finishes after a newer one
    // started is finalized rather than kept.
    var token = (el.aobToken || 0) + 1;
    el.aobToken = token;
    if (el.aob) {
      el.aob.finalize();
      el.aob = null;
    }
    if (!x) {
      el.textContent = "";
      delete el.dataset.aobStatus;
      return;
    }
    if (x.theme === "light" || x.theme === "dark") el.dataset.theme = x.theme;
    else delete el.dataset.theme;
    var scene;
    try {
      scene = JSON.parse(x.scene);
    } catch (err) {
      el.dataset.aobStatus = "error";
      el.textContent = "This scene could not be drawn: " + err.message;
      return;
    }
    var blobs = x.blobs && typeof x.blobs === "object" && !Array.isArray(x.blobs) ? x.blobs : {};
    window.aob.render(el, scene, { blobs: blobs, channel: channelFor(el, x), serial: x.serial })
      .then(function (h) {
        if (el.aobToken === token) el.aob = h;
        else h.finalize();
      }, function () {});
  };
  binding.renderError = function (el, err) {
    el.aobToken = (el.aobToken || 0) + 1;
    if (el.aob) {
      el.aob.finalize();
      el.aob = null;
    }
    window.Shiny.OutputBinding.prototype.renderError.call(this, el, err);
  };
  window.Shiny.outputBindings.register(binding, "aobview.output");
})();
