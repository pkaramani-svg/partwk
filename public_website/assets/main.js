// Partwk Public Website - Client Script (Trilingual Engine & Accessible Carousel)

(function () {
  'use strict';

  var SUPPORTED_LANGS = ['en', 'ku', 'ar'];
  var DEFAULT_LANG = 'en';

  function getInitialLanguage() {
    try {
      var params = new URLSearchParams(window.location.search);
      var urlLang = params.get('lang');
      if (urlLang && SUPPORTED_LANGS.indexOf(urlLang) !== -1) {
        return urlLang;
      }
      var stored = localStorage.getItem('partwk_lang');
      if (stored && SUPPORTED_LANGS.indexOf(stored) !== -1) {
        return stored;
      }
      var navLang = (navigator.language || navigator.userLanguage || '').toLowerCase();
      if (navLang.startsWith('ku')) return 'ku';
      if (navLang.startsWith('ar')) return 'ar';
    } catch (e) {}
    return DEFAULT_LANG;
  }

  function setLanguage(lang) {
    if (SUPPORTED_LANGS.indexOf(lang) === -1) lang = DEFAULT_LANG;

    try {
      localStorage.setItem('partwk_lang', lang);
    } catch (e) {}

    var isRtl = (lang === 'ku' || lang === 'ar');
    document.documentElement.lang = lang;
    document.documentElement.dir = isRtl ? 'rtl' : 'ltr';

    // Update language switcher buttons
    var buttons = document.querySelectorAll('.lang-btn');
    buttons.forEach(function (btn) {
      if (btn.getAttribute('data-lang-btn') === lang) {
        btn.classList.add('active');
        btn.setAttribute('aria-pressed', 'true');
      } else {
        btn.classList.remove('active');
        btn.setAttribute('aria-pressed', 'false');
      }
    });

    // Toggle multi-lingual elements
    var langEls = document.querySelectorAll('[data-lang]');
    langEls.forEach(function (el) {
      if (el.getAttribute('data-lang') === lang) {
        el.style.display = '';
      } else {
        el.style.display = 'none';
      }
    });

    // Update document title if present
    var titleEl = document.querySelector('title[data-title-' + lang + ']');
    if (titleEl) {
      document.title = titleEl.getAttribute('data-title-' + lang);
    }
  }

  // Initialize Language Switcher
  function initLanguageSwitcher() {
    var initialLang = getInitialLanguage();
    setLanguage(initialLang);

    document.addEventListener('click', function (e) {
      var btn = e.target.closest('.lang-btn');
      if (btn) {
        var chosen = btn.getAttribute('data-lang-btn');
        if (chosen) {
          setLanguage(chosen);
        }
      }
    });
  }

  // Initialize Library Carousel
  function initLibraryCarousel() {
    var container = document.querySelector('.carousel-container');
    var track = document.querySelector('.carousel-track');
    if (!container || !track) return;

    var isReducedMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    // Clone children to create an infinite continuous marquee loop
    if (!isReducedMotion) {
      var items = Array.prototype.slice.call(track.children);
      items.forEach(function (item) {
        var clone = item.cloneNode(true);
        clone.setAttribute('aria-hidden', 'true');
        track.appendChild(clone);
      });
    }

    // Pause controls on user interaction
    function pause() {
      track.classList.add('is-paused');
    }
    function resume() {
      track.classList.remove('is-paused');
    }

    container.addEventListener('mouseenter', pause);
    container.addEventListener('mouseleave', resume);
    container.addEventListener('touchstart', pause, { passive: true });
    container.addEventListener('touchend', resume, { passive: true });
    container.addEventListener('focusin', pause);
    container.addEventListener('focusout', resume);

    // Prev / Next button step scrolling
    var prevBtn = document.querySelector('.carousel-prev');
    var nextBtn = document.querySelector('.carousel-next');

    if (prevBtn) {
      prevBtn.addEventListener('click', function () {
        pause();
        container.scrollBy({ left: -240, behavior: 'smooth' });
      });
    }
    if (nextBtn) {
      nextBtn.addEventListener('click', function () {
        pause();
        container.scrollBy({ left: 240, behavior: 'smooth' });
      });
    }
  }

  // Run on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      initLanguageSwitcher();
      initLibraryCarousel();
    });
  } else {
    initLanguageSwitcher();
    initLibraryCarousel();
  }
})();
