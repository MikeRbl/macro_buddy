import React, { useState, useEffect } from 'react';
import { WorkoutSession, Exercise } from '../types';

interface WorkoutDetailModalProps {
  workout: WorkoutSession;
  defaultTimerSecs: number;
  onClose: () => void;
  onCompleteWorkout: (workoutId: string) => void;
}

export const WorkoutDetailModal: React.FC<WorkoutDetailModalProps> = ({
  workout,
  defaultTimerSecs,
  onClose,
  onCompleteWorkout,
}) => {
  const [exercises, setExercises] = useState<Exercise[]>(workout.exercises);
  const [timerSeconds, setTimerSeconds] = useState(defaultTimerSecs);
  const [timerRunning, setTimerRunning] = useState(false);
  const [completedSetsState, setCompletedSetsState] = useState<Record<string, boolean[]>>(() => {
    const initial: Record<string, boolean[]> = {};
    workout.exercises.forEach((ex) => {
      initial[ex.id] = new Array(ex.sets).fill(workout.completed);
    });
    return initial;
  });

  // Sound chime using Web Audio API
  const playChime = () => {
    try {
      const audioCtx = new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)();
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.type = 'sine';
      osc.frequency.setValueAtTime(587.33, audioCtx.currentTime); // D5
      osc.frequency.exponentialRampToValueAtTime(880, audioCtx.currentTime + 0.15); // A5
      gain.gain.setValueAtTime(0.3, audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.5);
      osc.start();
      osc.stop(audioCtx.currentTime + 0.5);
    } catch {
      // AudioContext unavailable or blocked
    }
  };

  // Timer countdown
  useEffect(() => {
    let interval: number | undefined;
    if (timerRunning && timerSeconds > 0) {
      interval = window.setInterval(() => {
        setTimerSeconds((prev) => {
          if (prev <= 1) {
            playChime();
            setTimerRunning(false);
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [timerRunning, timerSeconds]);

  const toggleSet = (exId: string, setIndex: number) => {
    setCompletedSetsState((prev) => {
      const currentSets = [...(prev[exId] || [])];
      currentSets[setIndex] = !currentSets[setIndex];
      // If completed a set, start timer automatically
      if (currentSets[setIndex]) {
        setTimerSeconds(defaultTimerSecs);
        setTimerRunning(true);
      }
      return { ...prev, [exId]: currentSets };
    });
  };

  const updateWeight = (exId: string, delta: number) => {
    setExercises((prev) =>
      prev.map((ex) =>
        ex.id === exId
          ? { ...ex, targetWeightKg: Math.max(0, +(ex.targetWeightKg + delta).toFixed(1)) }
          : ex
      )
    );
  };

  const handleFinish = () => {
    onCompleteWorkout(workout.id);
    onClose();
  };

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/70 backdrop-blur-md p-0 sm:p-4">
      <div className="w-full max-w-lg max-h-[90vh] bg-[#12141a] border border-white/10 rounded-t-3xl sm:rounded-3xl flex flex-col overflow-hidden shadow-2xl animate-in slide-in-from-bottom duration-200">
        {/* Top Header Bar */}
        <div className="p-5 pb-3 border-b border-white/10 flex items-start justify-between bg-[#161820]/90">
          <div>
            <div className="flex items-center gap-2">
              <span className="text-[10px] font-bold uppercase tracking-wider text-[#00E5FF] bg-[#00E5FF]/10 px-2 py-0.5 rounded-md">
                Min Max Personal
              </span>
              <span className="text-xs text-neutral-400">~{workout.durationMin} min</span>
            </div>
            <h2 className="text-2xl font-bold text-white mt-1">{workout.name}</h2>
            <div className="flex flex-wrap gap-1.5 mt-2">
              {workout.muscleTags.map((tag) => (
                <span
                  key={tag}
                  className="px-2 py-0.5 rounded-md text-[10px] font-semibold bg-neutral-800 text-neutral-300 border border-white/5"
                >
                  {tag}
                </span>
              ))}
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-9 h-9 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-neutral-300 hover:text-white transition cursor-pointer"
          >
            ✕
          </button>
        </div>

        {/* Floating Mini Rest Timer Bar */}
        <div className="bg-[#1a1d26] px-5 py-2.5 border-b border-white/10 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div
              className={`w-3 h-3 rounded-full ${
                timerRunning ? 'bg-[#00E5FF] animate-ping' : 'bg-neutral-600'
              }`}
            />
            <span className="text-xs text-neutral-300 font-medium">Temporizador de descanso:</span>
            <span className="font-mono text-base font-bold text-[#00E5FF] tabular-nums">
              {formatTime(timerSeconds)}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setTimerRunning(!timerRunning)}
              className="px-3 py-1 text-xs rounded-full bg-white/10 hover:bg-white/20 text-white font-medium transition cursor-pointer"
            >
              {timerRunning ? 'Pausar' : 'Iniciar'}
            </button>
            <button
              onClick={() => {
                setTimerRunning(false);
                setTimerSeconds(defaultTimerSecs);
              }}
              className="px-2.5 py-1 text-xs rounded-full bg-neutral-800 text-neutral-400 hover:text-white transition cursor-pointer"
            >
              Reiniciar
            </button>
          </div>
        </div>

        {/* Exercises Scrollable List */}
        <div className="p-5 overflow-y-auto space-y-4 no-scrollbar flex-1">
          {exercises.map((ex, idx) => {
            const setsArray = completedSetsState[ex.id] || new Array(ex.sets).fill(false);
            return (
              <div
                key={ex.id}
                className="bg-[#1b1e27]/80 rounded-2xl p-4 border border-white/5 space-y-3"
              >
                <div className="flex items-start justify-between">
                  <div>
                    <span className="text-[11px] font-bold text-[#00E5FF]">
                      0{idx + 1}. {ex.muscle.toUpperCase()}
                    </span>
                    <h3 className="text-base font-bold text-white mt-0.5">{ex.name}</h3>
                    {ex.notes && <p className="text-xs text-neutral-400 mt-0.5">{ex.notes}</p>}
                  </div>
                  {/* Weight adjuster */}
                  <div className="flex items-center gap-1.5 bg-[#0e0f14] px-2 py-1 rounded-xl border border-white/10">
                    <button
                      onClick={() => updateWeight(ex.id, -2.5)}
                      className="w-6 h-6 rounded bg-white/10 hover:bg-white/20 text-neutral-300 text-xs flex items-center justify-center cursor-pointer"
                    >
                      -
                    </button>
                    <span className="font-mono text-xs font-bold text-white tabular-nums px-1">
                      {ex.targetWeightKg} kg
                    </span>
                    <button
                      onClick={() => updateWeight(ex.id, 2.5)}
                      className="w-6 h-6 rounded bg-white/10 hover:bg-white/20 text-neutral-300 text-xs flex items-center justify-center cursor-pointer"
                    >
                      +
                    </button>
                  </div>
                </div>

                {/* Sets Grid */}
                <div className="grid grid-cols-3 sm:grid-cols-4 gap-2 pt-1">
                  {setsArray.map((isDone, setIdx) => (
                    <button
                      key={setIdx}
                      onClick={() => toggleSet(ex.id, setIdx)}
                      className={`py-2 px-2.5 rounded-xl text-left border transition-all cursor-pointer flex flex-col justify-between ${
                        isDone
                          ? 'bg-[#00E5FF]/15 border-[#00E5FF] text-[#00E5FF]'
                          : 'bg-[#0e0f14] border-white/5 text-neutral-300 hover:border-white/20'
                      }`}
                    >
                      <div className="flex items-center justify-between text-[11px] font-bold">
                        <span>SERIE {setIdx + 1}</span>
                        <span>{isDone ? '✓' : '○'}</span>
                      </div>
                      <div className="mt-1 text-xs font-mono font-medium">
                        {ex.reps} reps
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            );
          })}
        </div>

        {/* Bottom Action Footer */}
        <div className="p-4 bg-[#161820] border-t border-white/10 flex items-center gap-3">
          <button
            onClick={onClose}
            className="py-3 px-5 rounded-full bg-neutral-800 text-neutral-300 text-sm font-medium hover:text-white transition cursor-pointer"
          >
            Cancelar
          </button>
          <button
            onClick={handleFinish}
            className="flex-1 py-3 px-6 rounded-full bg-[#00E5FF] hover:bg-[#00daf3] text-black text-sm font-bold shadow-teal-glow active:scale-95 transition-all flex items-center justify-center gap-2 cursor-pointer"
          >
            <svg className="w-5 h-5 fill-none stroke-current" viewBox="0 0 24 24">
              <path d="M5 13l4 4L19 7" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" />
            </svg>
            <span>Finalizar y Guardar Sesión</span>
          </button>
        </div>
      </div>
    </div>
  );
};
