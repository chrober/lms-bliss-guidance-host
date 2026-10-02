(function () {
  'use strict';

  function setControlsVisible(section, enabled) {
    var controls = section.querySelector('[data-guidance-controls]');
    if (!controls) return;
    controls.classList.toggle('guidance-provider-controls-hidden', !enabled);
    controls.setAttribute('aria-hidden', enabled ? 'false' : 'true');
  }

  function resetInherited(control) {
    var value = control.querySelector('[data-guidance-value]');
    if (!value) return;
    value.value = value.getAttribute('data-guidance-inherited');
    var slider = control.querySelector('[data-guidance-slider]');
    if (slider) slider.value = value.value;
    var origin = control.querySelector('[data-guidance-origin]');
    if (origin) origin.textContent = 'Effective value source: Provider setting.';
    var reset = control.querySelector('[data-guidance-reset]');
    if (reset) reset.hidden = true;
  }

  function bind(root) {
    root.querySelectorAll('[data-guidance-enable]').forEach(function (checkbox) {
      checkbox.addEventListener('change', function () {
        setControlsVisible(checkbox.closest('[data-guidance-provider]'), checkbox.checked);
      });
    });
    root.querySelectorAll('[data-guidance-reset]').forEach(function (button) {
      button.addEventListener('click', function () {
        resetInherited(button.closest('[data-guidance-control]'));
      });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { bind(document); });
  } else {
    bind(document);
  }
}());
