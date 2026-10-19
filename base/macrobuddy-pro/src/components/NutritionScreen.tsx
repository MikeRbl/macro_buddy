import React, { useState } from 'react';
import { CoachPlan, Meal, FoodItem } from '../types';

interface NutritionScreenProps {
  coachPlan: CoachPlan;
  meals: Meal[];
  onAddFoodItem: (mealId: string, item: Omit<FoodItem, 'id'>) => void;
  onDeleteFoodItem: (mealId: string, itemId: string) => void;
  onOpenCoachPlan: () => void;
}

export const NutritionScreen: React.FC<NutritionScreenProps> = ({
  coachPlan,
  meals,
  onAddFoodItem,
  onDeleteFoodItem,
  onOpenCoachPlan,
}) => {
  const [selectedMealId, setSelectedMealId] = useState<string | null>(null);
  const [foodName, setFoodName] = useState('');
  const [foodCal, setFoodCal] = useState('');
  const [foodP, setFoodP] = useState('');
  const [foodC, setFoodC] = useState('');
  const [foodF, setFoodF] = useState('');
  const [foodPortion, setFoodPortion] = useState('1 porción');

  // Compute consumed totals
  const totalCalories = meals.reduce(
    (acc, m) => acc + m.items.reduce((sum, item) => sum + item.calories, 0),
    0
  );
  const totalProtein = meals.reduce(
    (acc, m) => acc + m.items.reduce((sum, item) => sum + item.protein, 0),
    0
  );
  const totalCarbs = meals.reduce(
    (acc, m) => acc + m.items.reduce((sum, item) => sum + item.carbs, 0),
    0
  );
  const totalFat = meals.reduce(
    (acc, m) => acc + m.items.reduce((sum, item) => sum + item.fat, 0),
    0
  );

  const remainingCal = Math.max(0, coachPlan.targetCalories - totalCalories);
  const calPercent = Math.min(100, Math.round((totalCalories / coachPlan.targetCalories) * 100));

  const handleAddSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedMealId || !foodName.trim() || !foodCal) return;
    onAddFoodItem(selectedMealId, {
      name: foodName.trim(),
      calories: parseInt(foodCal, 10) || 0,
      protein: parseInt(foodP, 10) || 0,
      carbs: parseInt(foodC, 10) || 0,
      fat: parseInt(foodF, 10) || 0,
      portion: foodPortion.trim() || '1 porción',
    });
    setFoodName('');
    setFoodCal('');
    setFoodP('');
    setFoodC('');
    setFoodF('');
    setSelectedMealId(null);
  };

  return (
    <div className="bg-[#0A0B0E] text-white min-h-screen pb-32">
      <div className="max-w-md mx-auto px-5 pt-4 space-y-4">
        {/* Top Header */}
        <div className="flex items-center justify-between pt-1">
          <div>
            <h1 className="text-2xl font-bold tracking-tight text-white">Nutrición & Macros</h1>
            <p className="text-xs text-neutral-400">Objetivo diario prescrito por entrenador</p>
          </div>
          <div className="flex items-center gap-1.5 bg-[#1f162b] px-3 py-1 rounded-full border border-[#B388FF]/30">
            <span className="text-xs text-[#B388FF] font-medium">Modo Guiado</span>
            <span className="text-xs text-[#FF8E53]">🔒</span>
          </div>
        </div>

        {/* Coach Banner */}
        <div
          onClick={onOpenCoachPlan}
          className="p-3.5 rounded-2xl bg-gradient-to-r from-[#211438] to-[#151a26] border border-[#B388FF]/30 flex items-center justify-between cursor-pointer"
        >
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-[#B388FF]/20 flex items-center justify-center text-[#B388FF] text-xs font-bold">
              {coachPlan.coachInitials}
            </div>
            <div>
              <div className="flex items-center gap-1">
                <span className="text-xs font-bold text-white">{coachPlan.coachName}</span>
                <span className="text-[10px] text-[#00daf3]">● Activo</span>
              </div>
              <p className="text-[11px] text-[#d4bbff]">
                "Carga alta de carbohidratos para sesión intensa de pierna."
              </p>
            </div>
          </div>
          <span className="text-xs text-[#B388FF] font-semibold">Detalles</span>
        </div>

        {/* Big Calorie Ring & Target Breakdown */}
        <div className="liquid-glass rounded-3xl p-5 shadow-card-glass space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <span className="text-xs font-semibold text-neutral-400 uppercase tracking-wider">
                Consumo Total Hoy
              </span>
              <div className="flex items-baseline gap-2 mt-1">
                <span className="text-3xl font-extrabold text-white font-mono tabular-nums">
                  {totalCalories.toLocaleString()}
                </span>
                <span className="text-sm text-neutral-400 font-mono">
                  / {coachPlan.targetCalories.toLocaleString()} kcal
                </span>
              </div>
            </div>

            <div className="text-right">
              <span className="text-[11px] text-neutral-400 block">Restante</span>
              <span className="text-xl font-bold text-[#FF8E53] font-mono tabular-nums">
                {remainingCal.toLocaleString()}{' '}
                <span className="text-xs font-normal text-neutral-400">kcal</span>
              </span>
            </div>
          </div>

          {/* Bar */}
          <div className="w-full h-2.5 rounded-full bg-neutral-800 overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-[#FF6B6B] to-[#FF8E53] rounded-full transition-all duration-300"
              style={{ width: `${calPercent}%` }}
            />
          </div>

          {/* 3 Macro Progress Cards */}
          <div className="grid grid-cols-3 gap-2 pt-1">
            {/* Protein */}
            <div className="bg-[#12141c] p-3 rounded-2xl border border-white/5">
              <div className="text-[10px] font-bold uppercase text-[#FF6B6B]">Proteína</div>
              <div className="text-base font-bold text-white font-mono mt-0.5 tabular-nums">
                {totalProtein}
                <span className="text-xs text-neutral-400 font-normal">
                  /{coachPlan.targetProtein}g
                </span>
              </div>
              <div className="w-full h-1 bg-neutral-800 rounded-full mt-2 overflow-hidden">
                <div
                  className="h-full bg-[#FF6B6B] rounded-full"
                  style={{
                    width: `${Math.min(100, (totalProtein / coachPlan.targetProtein) * 100)}%`,
                  }}
                />
              </div>
            </div>

            {/* Carbs */}
            <div className="bg-[#12141c] p-3 rounded-2xl border border-white/5">
              <div className="text-[10px] font-bold uppercase text-[#FF8E53]">Carbos</div>
              <div className="text-base font-bold text-white font-mono mt-0.5 tabular-nums">
                {totalCarbs}
                <span className="text-xs text-neutral-400 font-normal">
                  /{coachPlan.targetCarbs}g
                </span>
              </div>
              <div className="w-full h-1 bg-neutral-800 rounded-full mt-2 overflow-hidden">
                <div
                  className="h-full bg-[#FF8E53] rounded-full"
                  style={{
                    width: `${Math.min(100, (totalCarbs / coachPlan.targetCarbs) * 100)}%`,
                  }}
                />
              </div>
            </div>

            {/* Fats */}
            <div className="bg-[#12141c] p-3 rounded-2xl border border-white/5">
              <div className="text-[10px] font-bold uppercase text-[#00E5FF]">Grasas</div>
              <div className="text-base font-bold text-white font-mono mt-0.5 tabular-nums">
                {totalFat}
                <span className="text-xs text-neutral-400 font-normal">
                  /{coachPlan.targetFat}g
                </span>
              </div>
              <div className="w-full h-1 bg-neutral-800 rounded-full mt-2 overflow-hidden">
                <div
                  className="h-full bg-[#00E5FF] rounded-full"
                  style={{
                    width: `${Math.min(100, (totalFat / coachPlan.targetFat) * 100)}%`,
                  }}
                />
              </div>
            </div>
          </div>
        </div>

        {/* Meals List */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-bold text-white">Comidas del Día</h2>
            <span className="text-xs text-neutral-400">{meals.length} comidas</span>
          </div>

          {meals.map((meal) => {
            const mealCals = meal.items.reduce((s, i) => s + i.calories, 0);
            const mealP = meal.items.reduce((s, i) => s + i.protein, 0);
            const mealC = meal.items.reduce((s, i) => s + i.carbs, 0);
            const mealF = meal.items.reduce((s, i) => s + i.fat, 0);

            return (
              <div
                key={meal.id}
                className="liquid-glass rounded-2xl p-4 border border-white/5 space-y-3"
              >
                <div className="flex items-center justify-between">
                  <div>
                    <span className="text-[10px] font-semibold text-neutral-400">{meal.time}</span>
                    <h3 className="text-base font-bold text-white">{meal.name}</h3>
                  </div>
                  <div className="text-right">
                    <span className="font-mono text-sm font-bold text-white">{mealCals} kcal</span>
                    <div className="text-[10px] font-mono text-neutral-400">
                      P:{mealP}g · C:{mealC}g · G:{mealF}g
                    </div>
                  </div>
                </div>

                {/* Items */}
                <div className="divide-y divide-white/5">
                  {meal.items.map((item) => (
                    <div
                      key={item.id}
                      className="py-2 flex items-center justify-between text-xs group"
                    >
                      <div>
                        <span className="text-neutral-200 font-medium">{item.name}</span>
                        <span className="text-[10px] text-neutral-400 ml-2">({item.portion})</span>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className="font-mono text-neutral-300">{item.calories} kcal</span>
                        <button
                          onClick={() => onDeleteFoodItem(meal.id, item.id)}
                          className="opacity-0 group-hover:opacity-100 text-neutral-500 hover:text-red-400 transition"
                          title="Eliminar"
                        >
                          ✕
                        </button>
                      </div>
                    </div>
                  ))}
                </div>

                {/* Add item button */}
                <button
                  onClick={() => setSelectedMealId(meal.id)}
                  className="w-full py-2 rounded-xl bg-white/5 hover:bg-white/10 text-xs text-neutral-300 font-medium transition cursor-pointer flex items-center justify-center gap-1"
                >
                  <span>+ Añadir alimento a {meal.name.split(' ')[0]}</span>
                </button>
              </div>
            );
          })}
        </div>
      </div>

      {/* Add Food Modal */}
      {selectedMealId && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-md p-0 sm:p-4">
          <div className="w-full max-w-md bg-[#161720] border border-white/10 rounded-t-3xl sm:rounded-3xl p-5 shadow-2xl animate-in slide-in-from-bottom">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-base font-bold text-white">Añadir Alimento</h3>
              <button
                onClick={() => setSelectedMealId(null)}
                className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-neutral-300 hover:text-white"
              >
                ✕
              </button>
            </div>
            <form onSubmit={handleAddSubmit} className="space-y-3">
              <div>
                <label className="text-[11px] text-neutral-400 block mb-1">Nombre</label>
                <input
                  type="text"
                  placeholder="ej. Arroz basmati cocido"
                  value={foodName}
                  onChange={(e) => setFoodName(e.target.value)}
                  className="w-full bg-[#0e1017] border border-white/10 rounded-xl p-2.5 text-xs text-white focus:outline-none focus:border-[#FF8E53]"
                  autoFocus
                />
              </div>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="text-[10px] text-neutral-400 block mb-1">Porción</label>
                  <input
                    type="text"
                    placeholder="ej. 150g"
                    value={foodPortion}
                    onChange={(e) => setFoodPortion(e.target.value)}
                    className="w-full bg-[#0e1017] border border-white/10 rounded-xl p-2 text-xs text-white focus:outline-none focus:border-[#FF8E53]"
                  />
                </div>
                <div>
                  <label className="text-[10px] text-neutral-400 block mb-1">Calorías (kcal)</label>
                  <input
                    type="number"
                    placeholder="250"
                    value={foodCal}
                    onChange={(e) => setFoodCal(e.target.value)}
                    className="w-full bg-[#0e1017] border border-white/10 rounded-xl p-2 text-xs font-mono text-white text-center focus:outline-none focus:border-[#FF8E53]"
                  />
                </div>
              </div>
              <div className="grid grid-cols-3 gap-2">
                <div>
                  <label className="text-[10px] text-[#FF6B6B] block mb-1">Proteína (g)</label>
                  <input
                    type="number"
                    placeholder="g"
                    value={foodP}
                    onChange={(e) => setFoodP(e.target.value)}
                    className="w-full bg-[#0e1017] border border-white/10 rounded-xl p-2 text-xs font-mono text-white text-center focus:outline-none focus:border-[#FF6B6B]"
                  />
                </div>
                <div>
                  <label className="text-[10px] text-[#FF8E53] block mb-1">Carbos (g)</label>
                  <input
                    type="number"
                    placeholder="g"
                    value={foodC}
                    onChange={(e) => setFoodC(e.target.value)}
                    className="w-full bg-[#0e1017] border border-white/10 rounded-xl p-2 text-xs font-mono text-white text-center focus:outline-none focus:border-[#FF8E53]"
                  />
                </div>
                <div>
                  <label className="text-[10px] text-[#00E5FF] block mb-1">Grasa (g)</label>
                  <input
                    type="number"
                    placeholder="g"
                    value={foodF}
                    onChange={(e) => setFoodF(e.target.value)}
                    className="w-full bg-[#0e1017] border border-white/10 rounded-xl p-2 text-xs font-mono text-white text-center focus:outline-none focus:border-[#00E5FF]"
                  />
                </div>
              </div>
              <button
                type="submit"
                disabled={!foodName.trim() || !foodCal}
                className="w-full py-3 rounded-full bg-[#FF5757] text-white font-bold text-xs disabled:opacity-40 transition cursor-pointer"
              >
                Añadir Alimento
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
