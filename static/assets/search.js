(() => {
  const input = document.getElementById('sidebar-search');
  const list = document.getElementById('decl-list');
  if (!input || !list) return;

  const items = Array.from(list.querySelectorAll('.decl-item'));
  const labels = Array.from(list.querySelectorAll('.decl-group-label'));

  const filter = (q) => {
    const needle = q.trim().toLowerCase();
    items.forEach((it) => {
      const name = (it.dataset.name || it.textContent).toLowerCase();
      it.classList.toggle('hidden', needle.length > 0 && !name.includes(needle));
    });
    labels.forEach((label) => {
      let next = label.nextElementSibling;
      let anyVisible = false;
      while (next && !next.classList.contains('decl-group-label')) {
        if (next.classList.contains('decl-item') && !next.classList.contains('hidden')) {
          anyVisible = true; break;
        }
        next = next.nextElementSibling;
      }
      label.style.display = (needle.length > 0 && !anyVisible) ? 'none' : '';
    });
  };

  input.addEventListener('input', (e) => filter(e.target.value));

  document.addEventListener('keydown', (e) => {
    if (e.key === 's' && document.activeElement !== input) {
      e.preventDefault();
      input.focus();
    }
    if (e.key === 'Escape' && document.activeElement === input) {
      input.value = '';
      filter('');
      input.blur();
    }
    if (e.key === 'Enter' && document.activeElement === input) {
      const first = items.find((it) => !it.classList.contains('hidden'));
      if (first) window.location.href = first.getAttribute('href');
    }
  });
})();
