'use strict'

// Homepage is a React app and we don't have control over it
// Don't know of a way to detect the app loading in vanilla JS,
// So wait a bit and then inject the credit
setTimeout(() => {
  // Inject image credit into the version string
  // Structure:
  // <div id='version'> => <div> => <span (inject here)> => <a>version string</a>

  const versionContainer = document.getElementById('version').children[0].children[0]

  const credit = document.createElement('a')
  credit.href = 'https://www.pexels.com/@pixabay/'
  credit.target = '_blank'
  credit.rel = 'noopener noreferrer'
  credit.textContent = 'Background image credit: Pixabay'

  versionContainer.appendChild(credit)
}, 1000)
