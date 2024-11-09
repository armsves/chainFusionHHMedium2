import { useState } from 'react';
import { onChainOracle_backend } from 'declarations/onChainOracle_backend';

function App() {
  const [greeting, setGreeting] = useState('');

  function handleSubmit2(event) {
    event.preventDefault();
    onChainOracle_backend.getStoredData().then((greeting) => {
      setGreeting(greeting);
    });
    return false;
  }

  return (
    <main>
      <img src="/logo2.svg" alt="DFINITY logo" />
      <br />
      <form action="#" onSubmit={handleSubmit2}>
        <label htmlFor="name">Get stored data</label>
        <button type="submit">Click Me!</button>
      </form>
      {greeting &&
        <section id="greeting">Historical Data:
          {greeting.map((greeting, index) => (
            <div key={index}>{greeting}</div>
          ))}
        </section>}
    </main>
  );
}

export default App;
