document.addEventListener('DOMContentLoaded', () => {
  // Hero logic
  const carousel = document.getElementById('hero-carousel');
  const next = document.getElementById('nextBtn');
  const prev = document.getElementById('prevBtn');
  let index = 0;

  function updateHero() {
    carousel.style.transform = `translateX(-${index * 100}%)`;
  }

  next.addEventListener('click', () => {
    index = (index + 1) % 3;
    updateHero();
  });

  prev.addEventListener('click', () => {
    index = (index - 1 + 3) % 3;
    updateHero();
  });

  // Sample data
  const sampleProducts = {
    Electronics: Array.from({ length: 10 }, (_, i) => ({
      image: 'electronics.jpg',
      name: `Electronic ${i + 1}`,
      price: 15000,
      old_price: 45000,
    })),
    Fashion: Array.from({ length: 10 }, (_, i) => ({
      image: 'fashion.jpg',
      name: `Fashion ${i + 1}`,
      price: 30000,
      old_price: 90000,
    })),
    Home: Array.from({ length: 10 }, (_, i) => ({
      image: 'home.jpg',
      name: `Home ${i + 1}`,
      price: 50000,
      old_price: 150000,
    })),
    Toys: Array.from({ length: 10 }, (_, i) => ({
      image: 'toys.jpg',
      name: `Toy ${i + 1}`,
      price: 10000,
      old_price: 30000,
    })),
  };

  const container = document.getElementById('product-container');

  function renderCategory(name, products) {
    const section = document.createElement('div');
    section.innerHTML = `
      <h2 class="text-gold text-xl font-bold mb-2">${name}</h2>
      <div class="flex overflow-x-auto space-x-4">
        ${products
          .map(
            (p) => `
          <div class="flex flex-col items-center bg-white rounded-lg p-3 min-w-[170px] shadow-md">
            <img src="/images/${p.image}" class="product-img mb-2" alt="${p.name}" />
            <span class="text-charcoal text-center">${p.name}</span>
            <div class="text-center mt-2">
              <span class="text-red font-semibold text-lg">${p.price.toLocaleString()} UGX</span><br>
              <span class="line-through text-sm text-gray-500">${p.old_price.toLocaleString()} UGX</span>
            </div>
          </div>
        `
          )
          .join('')}
        <div class="flex items-center justify-center min-w-[170px] text-gold font-semibold">Show more →</div>
      </div>
    `;
    container.appendChild(section);
  }

  function renderAll() {
    container.innerHTML = '';
    for (const category in sampleProducts) {
      renderCategory(category, sampleProducts[category]);
    }
  }

  renderAll();

  document.querySelectorAll('.category').forEach((el) => {
    el.addEventListener('click', () => {
      const selected = el.dataset.category;
      container.innerHTML = '';
      renderCategory(selected, sampleProducts[selected]);
    });
  });
});