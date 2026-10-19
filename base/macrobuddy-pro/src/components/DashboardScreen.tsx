import React, { useState } from 'react';
import { UserProfile, CoachPlan, WorkoutSession } from '../types';

interface DashboardScreenProps {
  user: UserProfile;
  coachPlan: CoachPlan;
  workouts: WorkoutSession[];
  onStartTodayWorkout: (workout: WorkoutSession) => void;
  onNavigateToWorkout: () => void;
  onNavigateToNutrition: () => void;
  onNavigateToProfile: () => void;
}

export const DashboardScreen: React.FC<DashboardScreenProps> = ({
  user,
  coachPlan,
  workouts,
  onStartTodayWorkout,
  onNavigateToWorkout,
  onNavigateToNutrition,
  onNavigateToProfile,
}) => {
  const [waterMl, setWaterMl] = useState(2500);
  const targetWaterMl = 3500;
  const todayWorkout = workouts[0] || null;

  const currentCalories = 1985;
  const remainingCalories = coachPlan.targetCalories - currentCalories;
  const calPercent = Math.min(100, Math.round((currentCalories / coachPlan.targetCalories) * 100));

  const addWater = (amount: number) => {
    setWaterMl((prev) => Math.min(targetWaterMl + 1000, prev + amount));
  };

  return (
    <div className="bg-[#0A0B0E] text-white min-h-screen pb-32">
      <div className="max-w-md mx-auto px-5 pt-4 space-y-4">
        {/* Top Header */}
        <div className="flex items-center justify-between pt-1">
          <div className="flex items-center gap-3">
            <button
              onClick={onNavigateToProfile}
              className="relative p-0.5 rounded-full ring-2 ring-[#FF6B6B]/40 hover:ring-[#FF6B6B] transition cursor-pointer"
            >
              <img
                src={user.avatarUrl}
                alt={user.name}
                className="w-10 h-10 rounded-full object-cover"
                referrerPolicy="no-referrer"
              />
              <span className="w-3 h-3 rounded-full bg-[#00daf3] absolute bottom-0 right-0 ring-2 ring-[#0A0B0E]" />
            </button>
            <div>
              <div className="flex items-center gap-1.5">
                <h1 className="text-xl font-bold text-white">¡Hola, {user.name.split(' ')[0]}!</h1>
                <span className="text-[10px] font-bold text-[#FF6B6B] bg-[#FF6B6B]/15 px-2 py-0.5 rounded-full">
                  PRO ⚡
                </span>
              </div>
              <p className="text-xs text-neutral-400">Semana 5 • Lunes 12 de Octubre</p>
            </div>
          </div>

          <div className="flex items-center gap-1.5 bg-[#1b1d25] px-3 py-1.5 rounded-full border border-white/5">
            <span className="text-sm">🔥</span>
            <span className="font-mono text-xs font-bold text-[#FF8E53]">{user.streakDays}</span>
            <span className="text-[10px] text-neutral-400 uppercase">días</span>
          </div>
        </div>

        {/* Guided Coach Active Banner */}
        <div
          onClick={onNavigateToProfile}
          className="p-3 rounded-2xl bg-gradient-to-r from-[#211438] to-[#151a26] border border-[#B388FF]/30 flex items-center justify-between cursor-pointer group"
        >
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-[#B388FF]/20 flex items-center justify-center text-[#B388FF] text-xs font-bold">
              {coachPlan.coachInitials}
            </div>
            <div>
              <div className="flex items-center gap-1.5">
                <span className="text-xs font-bold text-white">{coachPlan.coachName}</span>
                <span className="w-1.5 h-1.5 rounded-full bg-[#00daf3]" />
              </div>
              <p className="text-[11px] text-[#d4bbff]">Modo Guiado Activo • Fase 2 Hipertrofia</p>
            </div>
          </div>
          <span className="text-xs text-[#B388FF] font-medium group-hover:translate-x-0.5 transition-transform">
            Ver plan →
          </span>
        </div>

        {/* Today's Workout Card */}
        {todayWorkout && (
          <div className="liquid-glass rounded-3xl p-5 shadow-card-glass space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-bold uppercase tracking-wider text-[#00E5FF]">
                Entrenamiento de Hoy
              </span>
              <span className="text-xs text-neutral-400">~{todayWorkout.durationMin} min</span>
            </div>

            <div>
              <h2 className="text-xl font-bold text-white">{todayWorkout.name}</h2>
              <p className="text-xs text-neutral-400 mt-1 line-clamp-2">
                {todayWorkout.description}
              </p>
            </div>

            <div className="flex flex-wrap gap-1.5">
              {todayWorkout.muscleTags.map((tag) => (
                <span
                  key={tag}
                  className="px-2 py-0.5 rounded-lg text-[10px] font-semibold bg-neutral-800 text-neutral-300 border border-white/5"
                >
                  {tag}
                </span>
              ))}
            </div>

            <div className="pt-2 flex items-center gap-3">
              <button
                onClick={() => onStartTodayWorkout(todayWorkout)}
                className="flex-1 py-3 px-4 rounded-full bg-[#00E5FF] hover:bg-[#00daf3] text-black font-bold text-sm shadow-teal-glow active:scale-95 transition flex items-center justify-center gap-2 cursor-pointer"
              >
                <svg className="w-5 h-5 fill-current" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z" />
                </svg>
                <span>{todayWorkout.completed ? 'Ver Sesión Registrada' : 'Iniciar Sesión'}</span>
              </button>
              <button
                onClick={onNavigateToWorkout}
                className="py-3 px-4 rounded-full bg-white/10 hover:bg-white/15 text-neutral-300 text-xs font-semibold transition cursor-pointer"
              >
                Ver todos
              </button>
            </div>
          </div>
        )}

        {/* Nutrition / Daily Calories Liquid Card */}
        <div
          onClick={onNavigateToNutrition}
          className="liquid-glass rounded-3xl p-5 shadow-card-glass space-y-3 cursor-pointer group"
        >
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold uppercase tracking-wider text-[#FF8E53]">
              Nutrición Diaria
            </span>
            <span className="text-xs text-neutral-400 flex items-center gap-1 font-mono">
              <span>{remainingCalories} kcal restantes</span>
              <span className="text-[#FF8E53]">🔒</span>
            </span>
          </div>

          <div className="flex items-baseline justify-between">
            <div>
              <span className="text-3xl font-extrabold text-white font-mono tabular-nums">
                {currentCalories.toLocaleString()}
              </span>
              <span className="text-sm text-neutral-400 font-mono">
                {' '}
                / {coachPlan.targetCalories.toLocaleString()} kcal
              </span>
            </div>
            <span className="text-xs font-bold text-[#FF8E53] font-mono">{calPercent}%</span>
          </div>

          {/* Progress Bar */}
          <div className="w-full h-2 rounded-full bg-neutral-800 overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-[#FF6B6B] to-[#FF8E53] rounded-full transition-all duration-500"
              style={{ width: `${calPercent}%` }}
            />
          </div>

          {/* Macros Strip */}
          <div className="grid grid-cols-3 gap-2 pt-1">
            <div className="bg-[#12141c] p-2.5 rounded-xl border border-white/5">
              <div className="flex items-center justify-between text-[11px]">
                <span className="text-neutral-400">Proteína</span>
                <span className="font-bold text-[#FF6B6B] font-mono">154/180g</span>
              </div>
              <div className="w-full h-1 bg-neutral-800 rounded-full mt-1.5 overflow-hidden">
                <div className="w-[85%] h-full bg-[#FF6B6B] rounded-full" />
              </div>
            </div>

            <div className="bg-[#12141c] p-2.5 rounded-xl border border-white/5">
              <div className="flex items-center justify-between text-[11px]">
                <span className="text-neutral-400">Carbs</span>
                <span className="font-bold text-[#FF8E53] font-mono">215/260g</span>
              </div>
              <div className="w-full h-1 bg-neutral-800 rounded-full mt-1.5 overflow-hidden">
                <div className="w-[83%] h-full bg-[#FF8E53] rounded-full" />
              </div>
            </div>

            <div className="bg-[#12141c] p-2.5 rounded-xl border border-white/5">
              <div className="flex items-center justify-between text-[11px]">
                <span className="text-neutral-400">Grasas</span>
                <span className="font-bold text-[#00E5FF] font-mono">52/65g</span>
              </div>
              <div className="w-full h-1 bg-neutral-800 rounded-full mt-1.5 overflow-hidden">
                <div className="w-[80%] h-full bg-[#00E5FF] rounded-full" />
              </div>
            </div>
          </div>
        </div>

        {/* Daily Hydration Card */}
        <div className="p-4 rounded-3xl bg-[#171a23]/70 backdrop-blur-xl border border-white/5 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-[#00daf3]/15 text-[#00daf3] flex items-center justify-center">
              <svg className="w-5 h-5 fill-none stroke-current" viewBox="0 0 24 24">
                <path
                  d="M12 2.69l5.66 5.66a8 8 0 11-11.31 0z"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2"
                />
              </svg>
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-neutral-200">Hidratación</span>
                <span className="font-mono text-xs text-[#00daf3] font-bold">
                  {(waterMl / 1000).toFixed(1)} / {(targetWaterMl / 1000).toFixed(1)} L
                </span>
              </div>
              <p className="text-[11px] text-neutral-400">Objetivo diario prescrito</p>
            </div>
          </div>

          <div className="flex items-center gap-1.5">
            <button
              onClick={() => addWater(250)}
              className="py-1.5 px-3 rounded-full bg-[#00daf3]/20 hover:bg-[#00daf3]/30 text-[#00daf3] font-bold text-xs transition cursor-pointer"
            >
              +250 ml
            </button>
            <button
              onClick={() => addWater(500)}
              className="py-1.5 px-3 rounded-full bg-[#00daf3]/20 hover:bg-[#00daf3]/30 text-[#00daf3] font-bold text-xs transition cursor-pointer"
            >
              +500 ml
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
