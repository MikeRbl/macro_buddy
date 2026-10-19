import React, { useState } from 'react';
import { WorkoutSession, RestDay, DayOption } from '../types';

interface WorkoutScreenProps {
  workouts: WorkoutSession[];
  restDays: RestDay[];
  carouselDays: DayOption[];
  selectedDayNum: number;
  onSelectDay: (dayNum: number) => void;
  onToggleWorkoutCompleted: (workoutId: string) => void;
  onOpenWorkoutDetail: (workout: WorkoutSession) => void;
  onOpenCalendarModal: () => void;
  onOpenAddWorkoutModal: () => void;
}

export const WorkoutScreen: React.FC<WorkoutScreenProps> = ({
  workouts,
  restDays,
  carouselDays,
  selectedDayNum,
  onSelectDay,
  onToggleWorkoutCompleted,
  onOpenWorkoutDetail,
  onOpenCalendarModal,
  onOpenAddWorkoutModal,
}) => {
  const [isProgramExpanded, setIsProgramExpanded] = useState(true);
  const [showOptionsMenu, setShowOptionsMenu] = useState(false);
  const [activeFilter, setActiveFilter] = useState<string | null>(null);

  // Filter workouts if muscle filter selected
  const displayedWorkouts = activeFilter
    ? workouts.filter((w) => w.muscleTags.includes(activeFilter))
    : workouts;

  return (
    <div className="text-white min-h-screen pb-32 selection:bg-[#00E5FF] selection:text-black">
      <div className="max-w-md mx-auto min-h-screen relative flex flex-col justify-between">
        {/* BEGIN: TopBarAndCalendar */}
        <header className="sticky top-0 z-40 bg-[#0A0B0E]/90 backdrop-blur-md pt-3 pb-2 px-5">
          {/* iOS Status Bar Simulation */}
          <div className="flex items-center justify-between text-xs font-semibold text-neutral-300 mb-3 tracking-tight">
            <span>9:41</span>
            <div className="flex items-center space-x-2">
              {/* Signal Icon */}
              <svg className="w-3.5 h-3.5 fill-current" viewBox="0 0 24 24">
                <path d="M12 3c-4.97 0-9 4.03-9 9 0 2.12.74 4.07 1.97 5.61L12 22l7.03-4.39C20.26 16.07 21 14.12 21 12c0-4.97-4.03-9-9-9zm0 2c3.87 0 7 3.13 7 7 0 1.54-.5 2.97-1.35 4.14L12 19.64l-5.65-3.5C5.5 14.97 5 13.54 5 12c0-3.87 3.13-7 7-7z" />
              </svg>
              {/* Wifi Icon */}
              <svg className="w-3.5 h-3.5 fill-current" viewBox="0 0 24 24">
                <path d="M12 4C7.31 4 3.07 5.9 0 8.98L12 21 24 8.98A16.88 16.88 0 0012 4zm0 3.5c3.55 0 6.78 1.34 9.24 3.54L12 19.34 2.76 11.04C5.22 8.84 8.45 7.5 12 7.5z" />
              </svg>
              {/* Battery Icon */}
              <div className="w-6 h-3 rounded-full border border-neutral-400 p-0.5 flex items-center">
                <div className="w-4 h-full bg-white rounded-full" />
              </div>
            </div>
          </div>

          {/* Main Workout Header */}
          <div className="flex items-center justify-between mt-1 mb-4 relative">
            <h1 className="text-3xl font-extrabold tracking-wider text-white uppercase font-sans">
              Workout
            </h1>
            <div className="flex items-center gap-2">
              {/* Calendar Button */}
              <button
                onClick={onOpenCalendarModal}
                aria-label="Calendario"
                className="w-10 h-10 rounded-full bg-neutral-800/80 border border-white/10 flex items-center justify-center text-neutral-300 hover:text-white hover:bg-neutral-700/80 transition-all cursor-pointer"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                  />
                </svg>
              </button>

              {/* Add Button */}
              <button
                onClick={onOpenAddWorkoutModal}
                aria-label="Añadir entrenamiento"
                className="w-10 h-10 rounded-full bg-neutral-800/80 border border-white/10 flex items-center justify-center text-neutral-300 hover:text-white hover:bg-neutral-700/80 transition-all cursor-pointer"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    d="M12 4v16m8-8H4"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2.2"
                  />
                </svg>
              </button>

              {/* More Options Button */}
              <button
                onClick={() => setShowOptionsMenu(!showOptionsMenu)}
                aria-label="Más opciones"
                className="w-10 h-10 rounded-full bg-neutral-800/80 border border-white/10 flex items-center justify-center text-neutral-300 hover:text-white hover:bg-neutral-700/80 transition-all cursor-pointer"
              >
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <circle cx="12" cy="6" r="2" />
                  <circle cx="12" cy="12" r="2" />
                  <circle cx="12" cy="18" r="2" />
                </svg>
              </button>
            </div>

            {/* Options Dropdown Menu */}
            {showOptionsMenu && (
              <div className="absolute right-0 top-12 w-56 rounded-2xl liquid-glass-elevated py-2 z-50 shadow-2xl border border-white/10">
                <button
                  onClick={() => {
                    setActiveFilter(null);
                    setShowOptionsMenu(false);
                  }}
                  className="w-full px-4 py-2 text-left text-xs text-neutral-200 hover:bg-white/10 flex items-center justify-between"
                >
                  <span>Mostrar todos</span>
                  {!activeFilter && <span className="text-[#00E5FF]">✓</span>}
                </button>
                <button
                  onClick={() => {
                    setActiveFilter('Chest');
                    setShowOptionsMenu(false);
                  }}
                  className="w-full px-4 py-2 text-left text-xs text-neutral-200 hover:bg-white/10 flex items-center justify-between"
                >
                  <span>Filtrar por Pecho</span>
                  {activeFilter === 'Chest' && <span className="text-[#00E5FF]">✓</span>}
                </button>
                <button
                  onClick={() => {
                    setActiveFilter('Biceps');
                    setShowOptionsMenu(false);
                  }}
                  className="w-full px-4 py-2 text-left text-xs text-neutral-200 hover:bg-white/10 flex items-center justify-between"
                >
                  <span>Filtrar por Brazos</span>
                  {activeFilter === 'Biceps' && <span className="text-[#00E5FF]">✓</span>}
                </button>
                <button
                  onClick={() => {
                    setActiveFilter('Hamstrings');
                    setShowOptionsMenu(false);
                  }}
                  className="w-full px-4 py-2 text-left text-xs text-neutral-200 hover:bg-white/10 flex items-center justify-between"
                >
                  <span>Filtrar por Piernas</span>
                  {activeFilter === 'Hamstrings' && <span className="text-[#00E5FF]">✓</span>}
                </button>
                <div className="border-t border-white/10 my-1" />
                <button
                  onClick={() => {
                    workouts.forEach((w) => {
                      if (w.completed) onToggleWorkoutCompleted(w.id);
                    });
                    setShowOptionsMenu(false);
                  }}
                  className="w-full px-4 py-2 text-left text-xs text-neutral-400 hover:text-white hover:bg-white/10"
                >
                  Reiniciar casillas
                </button>
              </div>
            )}
          </div>

          {/* Weekly Horizontal Day Selector Carousel */}
          <div className="flex items-center gap-2.5 overflow-x-auto no-scrollbar py-2 -mx-1 px-1">
            {carouselDays.map((d) => {
              const isActive = d.dayNum === selectedDayNum;
              return (
                <button
                  key={d.dayNum}
                  onClick={() => onSelectDay(d.dayNum)}
                  className={`flex flex-col items-center justify-center min-w-[50px] h-[72px] rounded-full transition-all cursor-pointer relative ${
                    isActive
                      ? 'bg-[#00E5FF]/10 border-2 border-[#00E5FF] shadow-teal-glow'
                      : 'bg-neutral-900/90 border border-white/5 hover:border-white/20 text-neutral-400'
                  }`}
                >
                  <span
                    className={`text-base leading-none ${
                      isActive ? 'font-bold text-[#00E5FF]' : 'font-semibold text-neutral-200'
                    }`}
                  >
                    {d.dayNum}
                  </span>
                  <span
                    className={`text-xs mt-1 ${
                      isActive ? 'font-medium text-[#00E5FF]/90' : 'font-normal'
                    }`}
                  >
                    {d.dayName}
                  </span>
                  {d.hasDot && !isActive && (
                    <span className="w-1.5 h-1.5 rounded-full bg-white/70 absolute bottom-2" />
                  )}
                </button>
              );
            })}
          </div>
        </header>
        {/* END: TopBarAndCalendar */}

        {/* BEGIN: MainContent */}
        <main className="px-5 pt-3 flex-1 space-y-4">
          {/* Section Title & Meta */}
          <div className="flex items-center justify-between pt-2">
            <h2 className="text-2xl font-bold tracking-tight text-white">Active Program</h2>
            <span className="text-sm font-medium text-neutral-400 tracking-wide underline underline-offset-4 decoration-neutral-600">
              Week 5
            </span>
          </div>

          {/* Collapsible Main Program Card */}
          <div className="liquid-glass rounded-3xl p-5 shadow-card-glass transition-all">
            {/* Header Collapsible Bar */}
            <div
              onClick={() => setIsProgramExpanded(!isProgramExpanded)}
              className="flex items-center justify-between pb-4 border-b border-white/10 cursor-pointer"
            >
              <div className="flex items-center gap-3.5">
                {/* Program Icon (Rocket / Cyan Accent) */}
                <div className="w-12 h-12 rounded-2xl bg-[#00B4D8] flex items-center justify-center shadow-lg shadow-cyan-500/25">
                  <svg
                    className="w-6 h-6 text-white"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2.2"
                    viewBox="0 0 24 24"
                  >
                    <path
                      d="M15.59 14.37a6 6 0 01-5.84 7.38v-4.8m5.84-2.58a14.98 14.98 0 006.16-12.12A14.98 14.98 0 009.631 8.41m5.96 5.96a14.926 14.926 0 01-5.841 2.58m-.119-8.54a6 6 0 00-7.381 5.84h4.8m2.581-5.84a14.927 14.927 0 00-2.58 5.84m2.699 2.7c-.103.021-.207.041-.311.06a15.09 15.09 0 01-2.448-2.448 14.9 14.9 0 01.06-.312m0 0l2.699 2.7z"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                </div>
                <div>
                  <h3 className="text-lg font-bold text-white tracking-tight">Min Max Personal</h3>
                  <p className="text-xs text-neutral-400 font-medium">5 workouts • 2 rest days</p>
                </div>
              </div>

              {/* Collapse Toggle Arrow */}
              <button
                aria-label="Alternar programa"
                className="text-neutral-400 hover:text-white p-1"
              >
                <svg
                  className={`w-5 h-5 stroke-current stroke-2 transition-transform duration-200 ${
                    isProgramExpanded ? '' : 'rotate-180'
                  }`}
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <path d="M5 15l7-7 7 7" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </button>
            </div>

            {/* Workout Sessions List */}
            {isProgramExpanded && (
              <div className="divide-y divide-white/5 pt-1">
                {displayedWorkouts.map((workout) => (
                  <div
                    key={workout.id}
                    className="py-4.5 flex items-start justify-between gap-3 group transition-colors"
                  >
                    <div
                      onClick={() => onOpenWorkoutDetail(workout)}
                      className="space-y-1.5 flex-1 pr-2 cursor-pointer"
                    >
                      <div className="flex items-center gap-2">
                        <h4
                          className={`text-base font-bold transition-colors ${
                            workout.completed
                              ? 'line-through text-neutral-400'
                              : 'text-white group-hover:text-[#00E5FF]'
                          }`}
                        >
                          {workout.name}
                        </h4>
                        {workout.completed && (
                          <span className="text-[10px] font-semibold text-[#00E5FF] bg-[#00E5FF]/10 px-2 py-0.5 rounded-full">
                            Completado
                          </span>
                        )}
                      </div>
                      <p className="text-xs text-neutral-400 leading-relaxed font-normal line-clamp-2">
                        {workout.description}
                      </p>

                      {/* Muscle Tags Badges */}
                      <div className="flex flex-wrap gap-1.5 pt-1.5">
                        {workout.muscleTags.map((tag) => (
                          <span
                            key={tag}
                            className="px-2.5 py-1 rounded-lg text-[10px] font-semibold bg-neutral-800/90 text-neutral-300 border border-white/5"
                          >
                            {tag}
                          </span>
                        ))}
                      </div>
                    </div>

                    {/* Checkbox Element */}
                    <label className="mt-1 cursor-pointer flex items-center justify-center p-1">
                      <input
                        type="checkbox"
                        checked={workout.completed}
                        onChange={() => onToggleWorkoutCompleted(workout.id)}
                        className="w-6 h-6 rounded-lg bg-neutral-900 border border-white/20 text-[#00E5FF] focus:ring-0 focus:ring-offset-0 cursor-pointer accent-[#00E5FF] transition"
                      />
                    </label>
                  </div>
                ))}

                {/* Rest Day 1 Card */}
                {restDays[0] && (
                  <div className="py-4 flex items-center justify-between gap-3 bg-neutral-900/40 rounded-2xl p-3 my-2 border border-white/[0.04]">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-xl bg-indigo-500/15 border border-indigo-400/20 flex items-center justify-center text-indigo-300">
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth="2"
                          />
                        </svg>
                      </div>
                      <div>
                        <h5 className="text-sm font-semibold text-neutral-200">
                          {restDays[0].title}
                        </h5>
                        <p className="text-[11px] text-neutral-400">{restDays[0].subtitle}</p>
                      </div>
                    </div>
                    <span className="text-[10px] font-bold tracking-wider text-indigo-400 bg-indigo-500/10 px-2 py-1 rounded-md uppercase border border-indigo-500/20">
                      {restDays[0].badgeText}
                    </span>
                  </div>
                )}

                {/* Rest Day 2 Card */}
                {restDays[1] && (
                  <div className="py-4 flex items-center justify-between gap-3 bg-neutral-900/40 rounded-2xl p-3 my-2 border border-white/[0.04]">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-xl bg-teal-500/15 border border-teal-400/20 flex items-center justify-center text-teal-300">
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth="2"
                          />
                        </svg>
                      </div>
                      <div>
                        <h5 className="text-sm font-semibold text-neutral-200">
                          {restDays[1].title}
                        </h5>
                        <p className="text-[11px] text-neutral-400">{restDays[1].subtitle}</p>
                      </div>
                    </div>
                    <span className="text-[10px] font-bold tracking-wider text-teal-400 bg-teal-500/10 px-2 py-1 rounded-md uppercase border border-teal-500/20">
                      {restDays[1].badgeText}
                    </span>
                  </div>
                )}
              </div>
            )}
          </div>
        </main>
        {/* END: MainContent */}
      </div>
    </div>
  );
};
