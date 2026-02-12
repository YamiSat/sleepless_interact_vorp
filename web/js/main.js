import { createOptions } from "./createOptions.js";
import { fetchNui } from "./fetchNui.js";
import { onSelect, updateHighlight, setCurrentIndex } from "./controls.js";
import { resetHold, setDefaultColor } from "./controls.js";

const optionsWrapper = document.getElementById("options-wrapper");
const body = document.body;

window.addEventListener("message", (event) => {
  switch (event.data.action) {
    case "init": {
      // console.log("Inicializando UI para el recurso:", event.data.resource);
      // Aquí puedes agregar cualquier lógica de inicialización específica
      break;
    }

    case "visible": {
      body.style.visibility = event.data.value ? "visible" : "hidden";
      // console.log("Visibilidad de UI cambiada a:", event.data.value);
      break;
    }

    case "setOptions": {
      optionsWrapper.innerHTML = "";

      if (event.data.value.options) {
        for (const type in event.data.value.options) {
          event.data.value.options[type].forEach((data, id) => {
            createOptions(type, data, id + 1);
          });
        }
        if (event.data.value.resetIndex) {
          setCurrentIndex(0);
        }
      }
      break;
    }

    case "interact": {
      onSelect();
      break;
    }

    case "release": {
      resetHold();
      break;
    }

    case "setColor": {
      const c = event.data.value;
      const color = `rgb(${c[0]}, ${c[1]}, ${c[2]}, ${c[3] / 255})`;
      setDefaultColor(color);
      body.style.setProperty('--theme-color', color);
      break;
    }

    case "setCooldown": {
      body.style.opacity = event.data.value ? '0.3' : '1';
      const interactKey = document.getElementById("interact-key");
      interactKey.innerHTML = event.data.value ? `<i class="fa-regular fa-hourglass-half"></i>` : 'G';
      break;
    }

    case "scroll": {
      // Nuevo manejador para eventos de scroll desde Lua
      const direction = event.data.direction;
      const options = optionsWrapper.querySelectorAll(".option-container");
      if (options.length === 0) return;
      
      let currentIndex = parseInt(document.querySelector(".highlighted")?.dataset.index || "0");
      
      if (direction === "down") {
        currentIndex = (currentIndex + 1) % options.length;
      } else {
        currentIndex = (currentIndex - 1 + options.length) % options.length;
      }
      
      setCurrentIndex(currentIndex);
      updateHighlight();
      fetchNui("currentOption", [currentIndex + 1]);
      break;
    }
  }
});

window.addEventListener("load", async (event) => {
  try {
    console.log("Sleepless Interact UI cargando...");
    const response = await fetchNui("load", {});
    console.log("Sleepless Interact UI loaded successfully", response);
  } catch (error) {
    console.error("Error loading Sleepless Interact UI:", error);
  }
});