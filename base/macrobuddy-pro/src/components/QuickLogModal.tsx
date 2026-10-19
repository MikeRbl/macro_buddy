import React, { useState } from 'react';

interface QuickLogModalProps {
  currentWeight: number;
  unit: string;
  onClose: () => void;
  onLogWeight: (newWeight: number) => void;
  onLogMeal: (name: string, cal: number, p: number, c: number, f: number) => void;
  onStartQuickTimer: () => void;
  onOpenWorkoutsTab: () => void;
}

export const QuickLogModal: React.FC<QuickLogModalProps> = ({
  currentWeight,
  unit,
  onClose,
  onLogWeight,
  onLogMeal,
  onStartQuickTimer,
  onOpenWorkoutsTab,
}) => {
  const [activeSubView, setActiveSubView] = useState<'menu' | 'weight' | 'food'>('menu');
  const [weightInput, setWeightInput] = useState(currentWeight.toString());
  const [foodName, setFoodName] = useState('');
  const [foodCalories, setFoodCalories] = useState('');
  const [foodProtein, setFoodProtein] = useState('');
  const [foodCarbs, setFoodCarbs] = useState('');
  const [foodFat, setFoodFat] = useState('');

  const submitWeight = (e: React.FormEvent) => {
    e.preventDefault();
    const val = parseFloat(weightInput);
    if (!isNaN(val) && val > 30 && val < 300) {
      onLogWeight(val);
      onClose();
    }
  };

  const submitFood = (e: React.FormEvent) => {
    e.preventDefault();
    if (!foodName.trim() || !foodCalories) return;
    onLogMeal(
      foodName.trim(),
      parseInt(foodCalories, 10) || 0,
      parseInt(foodProtein, 10) || 0,
      parseInt(foodCarbs, 10) || 0,
      parseInt(foodFat, 10) || 0
    );
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-md p-0 sm:p-4">
      <div className="w-full max-w-md bg-[#161720] border border-white/10 rounded-t-3xl sm:rounded-3xl overflow-hidden shadow-2xl animate-in slide-in-from-bottom duration-200">
        {/* Header */}
        <div className="p-4 border-b border-white/10 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-full bg-[#FF5757] shadow-coral-glow flex items-center justify-center text-white font-bold">
              +
            </div>
            <div>
              <h3 className="text-base font-bold text-white">Registro Rápido</h3>
              <p className="text-[11px] text-neutral-400">Añade datos a tu jornada de hoy</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-neutral-300 hover:text-white transition cursor-pointer"
          >
            ✕
          </button>
        </div>

        {/* Content */}
        <div className="p-5">
          {activeSubView === 'menu' && (
            <div className="grid grid-cols-2 gap-3">
              <button
                onClick={() => {
                  onOpenWorkoutsTab();
                  onClose();
                }}
                className="p-4 rounded-2xl bg-[#20232e] hover:bg-[#282c3a] border border-white/5 flex flex-col items-start gap-2 transition text-left cursor-pointer group"
              >
                <div className="w-10 h-10 rounded-xl bg-[#00E5FF]/15 text-[#00E5FF] flex items-center justify-center group-hover:scale-105 transition-transform">
                  <svg className="w-5 h-5 fill-current" viewBox="0 0 24 24">
                    <path d="M6 5v14h3v-2h6v2h3V5h-3v2H9V5H6zm2 4h8v6H8V9z" />
                  </svg>
                </div>
                <span className="text-sm font-bold text-white">Entrenamiento</span>
                <span className="text-[11px] text-neutral-400">Ver rutina activa o registrar series</span>
              </button>

              <button
                onClick={() => setActiveSubView('food')}
                className="p-4 rounded-2xl bg-[#20232e] hover:bg-[#282c3a] border border-white/5 flex flex-col items-start gap-2 transition text-left cursor-pointer group"
              >
                <div className="w-10 h-10 rounded-xl bg-[#FF8E53]/15 text-[#FF8E53] flex items-center justify-center group-hover:scale-105 transition-transform">
                  <svg className="w-5 h-5 fill-none stroke-current" viewBox="0 0 24 24">
                    <path
                      d="M12 2a4 4 0 00-4 4c0 .34.04.67.11.98C5.28 7.6 3 10.3 3 13.5 3 17.64 6.36 21 10.5 21c2.14 0 4.09-.89 5.5-2.33 1.41 1.44 3.36 2.33 5.5 2.33 4.14 0 7.5-3.36 7.5-7.5 0-3.2-2.28-5.9-5.11-6.52.07-.31.11-.64.11-.98a4 4 0 00-4-4c-1.55 0-2.91.88-3.6 2.18-.32-.61-.79-1.12-1.37-1.49-.65-.43-1.42-.69-2.25-.69h-.28z"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                    />
                  </svg>
                </div>
                <span className="text-sm font-bold text-white">Comida / Macros</span>
                <span className="text-[11px] text-neutral-400">Registrar plato rápido o snack</span>
              </button>

              <button
                onClick={() => setActiveSubView('weight')}
                className="p-4 rounded-2xl bg-[#20232e] hover:bg-[#282c3a] border border-white/5 flex flex-col items-start gap-2 transition text-left cursor-pointer group"
              >
                <div className="w-10 h-10 rounded-xl bg-[#B388FF]/15 text-[#B388FF] flex items-center justify-center group-hover:scale-105 transition-transform">
                  <svg className="w-5 h-5 fill-none stroke-current" viewBox="0 0 24 24">
                    <path
                      d="M3 6l3 12h12l3-12H3zm9 3v4m-2 0h4"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                    />
                  </svg>
                </div>
                <span className="text-sm font-bold text-white">Peso Corporal</span>
                <span className="text-[11px] text-neutral-400">Check-in de peso en ayunas</span>
              </button>

              <button
                onClick={() => {
                  onStartQuickTimer();
                  onClose();
                }}
                className="p-4 rounded-2xl bg-[#20232e] hover:bg-[#282c3a] border border-white/5 flex flex-col items-start gap-2 transition text-left cursor-pointer group"
              >
                <div className="w-10 h-10 rounded-xl bg-[#00daf3]/15 text-[#00daf3] flex items-center justify-center group-hover:scale-105 transition-transform">
                  <svg className="w-5 h-5 fill-none stroke-current" viewBox="0 0 24 24">
                    <path
                      d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                    />
                  </svg>
                </div>
                <span className="text-sm font-bold text-white">Temporizador</span>
                <span className="text-[11px] text-neutral-400">90s descanso entre series</span>
              </button>
            </div>
          )}

          {activeSubView === 'weight' && (
            <form onSubmit={submitWeight} className="space-y-4">
              <div className="flex items-center justify-between">
                <button
                  type="button"
                  onClick={() => setActiveSubView('menu')}
                  className="text-xs text-neutral-400 hover:text-white flex items-center gap-1 cursor-pointer"
                >
                  ← Volver
                </button>
                <span className="text-xs font-semibold text-[#B388FF]">Check-in de Peso</span>
              </div>
              <div className="text-center py-2">
                <label className="text-xs text-neutral-400 block mb-1">Introduce tu peso de hoy</label>
                <div className="flex items-center justify-center gap-2">
                  <input
                    type="number"
                    step="0.1"
                    value={weightInput}
                    onChange={(e) => setWeightInput(e.target.value)}
                    className="w-32 bg-[#0e1017] border border-white/20 rounded-2xl px-4 py-3 text-2xl font-bold font-mono text-center text-white focus:outline-none focus:border-[#B388FF]"
                    autoFocus
                  />
                  <span className="text-lg font-bold text-neutral-400 font-mono">{unit}</span>
                </div>
              </div>
              <button
                type="submit"
                className="w-full py-3 rounded-full bg-gradient-to-r from-[#B388FF] to-[#b085fc] text-black font-bold text-sm shadow-purple-glow active:scale-95 transition cursor-pointer"
              >
                Guardar Check-in
              </button>
            </form>
          )}

          {activeSubView === 'food' && (
            <form onSubmit={submitFood} className="space-y-3">
              <div className="flex items-center justify-between">
                <button
                  type="button"
                  onClick={() => setActiveSubView('menu')}
                  className="text-xs text-neutral-400 hover:text-white flex items-center gap-1 cursor-pointer"
                >
                  ← Volver
                </button>
                <span className="text-xs font-semibold text-[#FF8E53]">Nuevo Alimento</span>
              </div>
              <div>
                <label className="text-[11px] text-neutral-400 block mb-1">Nombre del alimento</label>
                <input
                  type="text"
                  placeholder="ej. Batido de Proteína con Avena"
                  value={foodName}
                  onChange={(e) => setFoodName(e.target.value)}
                  className="w-full bg-[#0e1017] border border-white/10 rounded-xl p-2.5 text-xs text-white focus:outline-none focus:border-[#FF8E53]"
                  autoFocus
                />
              </div>
              <div className="grid grid-cols-4 gap-2">
                <div>
                  <label className="text-[10px] text-neutral-400 block mb-1">Calorías</label>
                  <input
                    type="number"
                    placeholder="kcal"
                    value={foodCalories}
                    onChange={(e) => setFoodCalories(e.target.value)}
                    className="w-full bg-[#0e1017] border border-white/10 rounded-xl p-2 text-xs font-mono text-white text-center focus:outline-none focus:border-[#FF8E53]"
                  />
                </div>
                <div>
                  <label className="text-[10px] text-[#FF6B6B] block mb-1">Prot (g)</label>
                  <input
                    type="number"
                    placeholder="g"
                    value={foodProtein}
                    onChange={(e) => setFoodProtein(e.target.value)}
                    className="w-full bg-[#0e1017] border border-white/10 rounded-xl p-2 text-xs font-mono text-white text-center focus:outline-none focus:border-[#FF6B6B]"
                  />
                </div>
                <div>
                  <label className="text-[10px] text-[#FF8E53] block mb-1">Carb (g)</label>
                  <input
                    type="number"
                    placeholder="g"
                    value={foodCarbs}
                    onChange={(e) => setFoodCarbs(e.target.value)}
                    className="w-full bg-[#0e1017] border border-white/10 rounded-xl p-2 text-xs font-mono text-white text-center focus:outline-none focus:border-[#FF8E53]"
                  />
                </div>
                <div>
                  <label className="text-[10px] text-[#00E5FF] block mb-1">Grasa (g)</label>
                  <input
                    type="number"
                    placeholder="g"
                    value={foodFat}
                    onChange={(e) => setFoodFat(e.target.value)}
                    className="w-full bg-[#0e1017] border border-white/10 rounded-xl p-2 text-xs font-mono text-white text-center focus:outline-none focus:border-[#00E5FF]"
                  />
                </div>
              </div>
              <button
                type="submit"
                disabled={!foodName.trim() || !foodCalories}
                className="w-full mt-2 py-3 rounded-full bg-[#FF5757] hover:bg-[#ff6e6e] text-white font-bold text-sm shadow-coral-glow disabled:opacity-40 active:scale-95 transition cursor-pointer"
              >
                Añadir al Diario de Macros
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
};
