import React, { useState } from 'react';
import { UserProfile, CoachPlan, WorkoutSession } from '../types';

// Unidades de Medida Modal
export const UnitsModal: React.FC<{
  currentSystem: 'metric' | 'imperial';
  onSave: (val: 'metric' | 'imperial') => void;
  onClose: () => void;
}> = ({ currentSystem, onSave, onClose }) => {
  const [selected, setSelected] = useState(currentSystem);
  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/75 backdrop-blur-md p-0 sm:p-4">
      <div className="w-full max-w-md bg-[#161720] border border-white/10 rounded-t-3xl sm:rounded-3xl p-5 shadow-2xl animate-in slide-in-from-bottom">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-base font-bold text-white">Unidades de Medida</h3>
          <button onClick={onClose} className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-neutral-300">✕</button>
        </div>
        <div className="space-y-2 mb-5">
          <button
            onClick={() => setSelected('metric')}
            className={`w-full p-3.5 rounded-2xl border text-left flex items-center justify-between transition ${
              selected === 'metric' ? 'bg-[#00E5FF]/10 border-[#00E5FF] text-white' : 'bg-[#10121a] border-white/5 text-neutral-300'
            }`}
          >
            <div>
              <div className="font-semibold text-sm">Sistema Métrico</div>
              <div className="text-xs text-neutral-400">Kilogramos (kg), Centímetros (cm), kcal</div>
            </div>
            {selected === 'metric' && <span className="text-[#00E5FF] font-bold">✓</span>}
          </button>
          <button
            onClick={() => setSelected('imperial')}
            className={`w-full p-3.5 rounded-2xl border text-left flex items-center justify-between transition ${
              selected === 'imperial' ? 'bg-[#00E5FF]/10 border-[#00E5FF] text-white' : 'bg-[#10121a] border-white/5 text-neutral-300'
            }`}
          >
            <div>
              <div className="font-semibold text-sm">Sistema Imperial</div>
              <div className="text-xs text-neutral-400">Libras (lbs), Pulgadas (in), kcal</div>
            </div>
            {selected === 'imperial' && <span className="text-[#00E5FF] font-bold">✓</span>}
          </button>
        </div>
        <button
          onClick={() => { onSave(selected); onClose(); }}
          className="w-full py-3 rounded-full bg-[#00E5FF] text-black font-bold text-sm shadow-teal-glow active:scale-95 transition"
        >
          Guardar Preferencia
        </button>
      </div>
    </div>
  );
};

// Health Integrations Modal
export const IntegrationsModal: React.FC<{
  healthSync: UserProfile['healthSync'];
  onSave: (sync: UserProfile['healthSync']) => void;
  onClose: () => void;
}> = ({ healthSync, onSave, onClose }) => {
  const [syncState, setSyncState] = useState({ ...healthSync });

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/75 backdrop-blur-md p-0 sm:p-4">
      <div className="w-full max-w-md bg-[#161720] border border-white/10 rounded-t-3xl sm:rounded-3xl p-5 shadow-2xl animate-in slide-in-from-bottom">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-base font-bold text-white">Integraciones de Salud</h3>
          <button onClick={onClose} className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-neutral-300">✕</button>
        </div>
        <div className="space-y-3 mb-5">
          <div className="p-3.5 rounded-2xl bg-[#10121a] border border-white/5 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="text-xl">🍎</span>
              <div>
                <div className="text-sm font-semibold text-white">Apple Health</div>
                <div className="text-xs text-neutral-400">Sincronización de pasos y calorías activas</div>
              </div>
            </div>
            <input
              type="checkbox"
              checked={syncState.appleHealth}
              onChange={() => setSyncState((s) => ({ ...s, appleHealth: !s.appleHealth }))}
              className="w-5 h-5 rounded accent-[#00E5FF]"
            />
          </div>
          <div className="p-3.5 rounded-2xl bg-[#10121a] border border-white/5 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="text-xl">🏃</span>
              <div>
                <div className="text-sm font-semibold text-white">Strava</div>
                <div className="text-xs text-neutral-400">Importación de sesiones de cardio y ritmo</div>
              </div>
            </div>
            <input
              type="checkbox"
              checked={syncState.strava}
              onChange={() => setSyncState((s) => ({ ...s, strava: !s.strava }))}
              className="w-5 h-5 rounded accent-[#00E5FF]"
            />
          </div>
          <div className="p-3.5 rounded-2xl bg-[#10121a] border border-white/5 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="text-xl">⚡</span>
              <div>
                <div className="text-sm font-semibold text-white">Google Fit / Health Connect</div>
                <div className="text-xs text-neutral-400">Sensores biométricos de sueño y FC</div>
              </div>
            </div>
            <input
              type="checkbox"
              checked={syncState.googleFit}
              onChange={() => setSyncState((s) => ({ ...s, googleFit: !s.googleFit }))}
              className="w-5 h-5 rounded accent-[#00E5FF]"
            />
          </div>
        </div>
        <button
          onClick={() => { onSave(syncState); onClose(); }}
          className="w-full py-3 rounded-full bg-[#00E5FF] text-black font-bold text-sm shadow-teal-glow active:scale-95 transition"
        >
          Guardar Conexiones
        </button>
      </div>
    </div>
  );
};

// Rest Timer Settings Modal
export const RestTimerModal: React.FC<{
  currentSeconds: number;
  onSave: (secs: number) => void;
  onClose: () => void;
}> = ({ currentSeconds, onSave, onClose }) => {
  const [selected, setSelected] = useState(currentSeconds);
  const presets = [45, 60, 90, 120, 180];

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/75 backdrop-blur-md p-0 sm:p-4">
      <div className="w-full max-w-md bg-[#161720] border border-white/10 rounded-t-3xl sm:rounded-3xl p-5 shadow-2xl animate-in slide-in-from-bottom">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-base font-bold text-white">Temporizador de Descanso</h3>
          <button onClick={onClose} className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-neutral-300">✕</button>
        </div>
        <p className="text-xs text-neutral-400 mb-4">
          Tiempo automático entre series sugerido para hipertrofia y recuperación neural.
        </p>
        <div className="grid grid-cols-3 gap-2.5 mb-5">
          {presets.map((s) => (
            <button
              key={s}
              onClick={() => setSelected(s)}
              className={`py-3 rounded-2xl border text-center transition ${
                selected === s ? 'bg-[#00daf3]/15 border-[#00daf3] text-[#00daf3]' : 'bg-[#10121a] border-white/5 text-neutral-300'
              }`}
            >
              <div className="text-lg font-bold font-mono">{s}s</div>
              <div className="text-[10px] text-neutral-400">{s >= 120 ? 'Compuestos' : 'Aislamiento'}</div>
            </button>
          ))}
        </div>
        <button
          onClick={() => { onSave(selected); onClose(); }}
          className="w-full py-3 rounded-full bg-[#00daf3] text-black font-bold text-sm active:scale-95 transition"
        >
          Guardar Temporizador ({selected}s)
        </button>
      </div>
    </div>
  );
};

// Gym & Equipment Modal
export const GymEquipmentModal: React.FC<{
  gymName: string;
  onSave: (name: string) => void;
  onClose: () => void;
}> = ({ gymName, onSave, onClose }) => {
  const [name, setName] = useState(gymName);

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/75 backdrop-blur-md p-0 sm:p-4">
      <div className="w-full max-w-md bg-[#161720] border border-white/10 rounded-t-3xl sm:rounded-3xl p-5 shadow-2xl animate-in slide-in-from-bottom">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-base font-bold text-white">Equipo & Gimnasio</h3>
          <button onClick={onClose} className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-neutral-300">✕</button>
        </div>
        <div className="space-y-4 mb-5">
          <div>
            <label className="text-xs text-neutral-400 block mb-1">Nombre del Centro de Entrenamiento</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full bg-[#10121a] border border-white/10 rounded-xl p-3 text-sm text-white focus:outline-none focus:border-[#FF6B6B]"
            />
          </div>
          <div className="p-3 rounded-xl bg-[#10121a] border border-white/5 space-y-2">
            <span className="text-xs font-semibold text-neutral-300">Equipamiento Confirmado:</span>
            <div className="grid grid-cols-2 gap-2 text-xs text-neutral-400">
              <div className="flex items-center gap-1.5"><span className="text-[#00E5FF]">✓</span> Barras Olímpicas & Racks</div>
              <div className="flex items-center gap-1.5"><span className="text-[#00E5FF]">✓</span> Mancuernas hasta 50kg</div>
              <div className="flex items-center gap-1.5"><span className="text-[#00E5FF]">✓</span> Estaciones de Poleas</div>
              <div className="flex items-center gap-1.5"><span className="text-[#00E5FF]">✓</span> Prensa de Piernas 45°</div>
            </div>
          </div>
        </div>
        <button
          onClick={() => { onSave(name); onClose(); }}
          className="w-full py-3 rounded-full bg-[#FF6B6B] text-white font-bold text-sm shadow-coral-glow active:scale-95 transition"
        >
          Guardar Centro
        </button>
      </div>
    </div>
  );
};

// Export Data Modal
export const ExportModal: React.FC<{
  user: UserProfile;
  coachPlan: CoachPlan;
  workouts: WorkoutSession[];
  onClose: () => void;
}> = ({ user, coachPlan, workouts, onClose }) => {
  const [downloaded, setDownloaded] = useState(false);

  const handleDownload = () => {
    const data = {
      athlete: user.name,
      athleteId: user.athleteId,
      weight: user.currentWeight,
      bodyFat: user.bodyFatPct,
      streak: user.streakDays,
      coach: coachPlan.coachName,
      targetCalories: coachPlan.targetCalories,
      macros: {
        protein: coachPlan.targetProtein,
        carbs: coachPlan.targetCarbs,
        fat: coachPlan.targetFat,
      },
      workoutsSummary: workouts.map((w) => ({
        name: w.name,
        completed: w.completed,
        exercisesCount: w.exercises.length,
      })),
      exportedAt: new Date().toISOString(),
    };

    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `macrobuddy_performance_${user.athleteId.replace('#', '')}.json`;
    a.click();
    URL.revokeObjectURL(url);
    setDownloaded(true);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/75 backdrop-blur-md p-0 sm:p-4">
      <div className="w-full max-w-md bg-[#161720] border border-white/10 rounded-t-3xl sm:rounded-3xl p-5 shadow-2xl animate-in slide-in-from-bottom">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-base font-bold text-white">Exportar Datos de Rendimiento</h3>
          <button onClick={onClose} className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-neutral-300">✕</button>
        </div>
        <p className="text-xs text-neutral-400 mb-4 leading-relaxed">
          Genera un archivo JSON compatible con hojas de cálculo, Strava y reportes de tu preparador físico con todas tus sesiones, cargas y macros.
        </p>
        <div className="p-3 rounded-2xl bg-[#10121a] border border-white/5 mb-5 space-y-1 text-xs text-neutral-300">
          <div>• Registro de {workouts.length} rutinas activas</div>
          <div>• Historial de peso corporal y porcentaje graso DEXA</div>
          <div>• Prescripción de macronutrientes del entrenador</div>
        </div>
        {downloaded ? (
          <div className="text-center py-2 text-[#00E5FF] font-semibold text-xs mb-3">
            ✓ Archivo descargado exitosamente
          </div>
        ) : null}
        <button
          onClick={handleDownload}
          className="w-full py-3 rounded-full bg-white text-black font-bold text-sm active:scale-95 transition"
        >
          Descargar JSON de Rendimiento
        </button>
      </div>
    </div>
  );
};

// Edit Profile Modal
export const EditProfileModal: React.FC<{
  user: UserProfile;
  onSave: (name: string, handle: string, weight: number) => void;
  onClose: () => void;
}> = ({ user, onSave, onClose }) => {
  const [name, setName] = useState(user.name);
  const [handle, setHandle] = useState(user.handle);
  const [weight, setWeight] = useState(user.currentWeight.toString());

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/75 backdrop-blur-md p-0 sm:p-4">
      <div className="w-full max-w-md bg-[#161720] border border-white/10 rounded-t-3xl sm:rounded-3xl p-5 shadow-2xl animate-in slide-in-from-bottom">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-base font-bold text-white">Editar Perfil</h3>
          <button onClick={onClose} className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-neutral-300">✕</button>
        </div>
        <div className="space-y-3 mb-5">
          <div>
            <label className="text-[11px] text-neutral-400 block mb-1">Nombre Completo</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full bg-[#10121a] border border-white/10 rounded-xl p-2.5 text-xs text-white focus:outline-none focus:border-[#FF6B6B]"
            />
          </div>
          <div>
            <label className="text-[11px] text-neutral-400 block mb-1">Usuario / Handle</label>
            <input
              type="text"
              value={handle}
              onChange={(e) => setHandle(e.target.value)}
              className="w-full bg-[#10121a] border border-white/10 rounded-xl p-2.5 text-xs text-white focus:outline-none focus:border-[#FF6B6B]"
            />
          </div>
          <div>
            <label className="text-[11px] text-neutral-400 block mb-1">Peso Actual (kg)</label>
            <input
              type="number"
              step="0.1"
              value={weight}
              onChange={(e) => setWeight(e.target.value)}
              className="w-full bg-[#10121a] border border-white/10 rounded-xl p-2.5 text-xs text-white focus:outline-none focus:border-[#FF6B6B]"
            />
          </div>
        </div>
        <button
          onClick={() => {
            const w = parseFloat(weight) || user.currentWeight;
            onSave(name.trim() || user.name, handle.trim() || user.handle, w);
            onClose();
          }}
          className="w-full py-3 rounded-full bg-gradient-to-r from-[#FF6B6B] to-[#FF8E53] text-white font-bold text-sm shadow-coral-glow active:scale-95 transition"
        >
          Guardar Cambios
        </button>
      </div>
    </div>
  );
};

// Unlink Coach Confirmation Modal
export const UnlinkCoachModal: React.FC<{
  coachName: string;
  isGuided: boolean;
  onToggle: () => void;
  onClose: () => void;
}> = ({ coachName, isGuided, onToggle, onClose }) => {
  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/75 backdrop-blur-md p-0 sm:p-4">
      <div className="w-full max-w-md bg-[#161720] border border-white/10 rounded-t-3xl sm:rounded-3xl p-5 shadow-2xl animate-in slide-in-from-bottom">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-base font-bold text-white">
            {isGuided ? '¿Desvincular Entrenador?' : '¿Reconectar Modo Guiado?'}
          </h3>
          <button onClick={onClose} className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-neutral-300">✕</button>
        </div>
        <p className="text-xs text-neutral-300 mb-4 leading-relaxed">
          {isGuided
            ? `Al desvincular a ${coachName}, se desbloqueará la edición manual de calorías y rutinas, pero tu entrenador ya no podrá sincronizar ajustes en tiempo real.`
            : `Reactivar el enlace profesional con ${coachName} sincronizará tus datos con su panel de control y volverá a bloquear las macros conforme a su prescripción.`}
        </p>
        <div className="flex gap-2.5">
          <button
            onClick={onClose}
            className="flex-1 py-3 rounded-full bg-white/10 hover:bg-white/20 text-neutral-300 text-xs font-semibold"
          >
            Cancelar
          </button>
          <button
            onClick={() => { onToggle(); onClose(); }}
            className={`flex-1 py-3 rounded-full font-bold text-xs transition ${
              isGuided ? 'bg-red-500/80 hover:bg-red-500 text-white' : 'bg-[#B388FF] text-black shadow-purple-glow'
            }`}
          >
            {isGuided ? 'Desvincular' : 'Activar Modo Guiado'}
          </button>
        </div>
      </div>
    </div>
  );
};

// Calendar Overview Modal (from Workout Screen Calendar button)
export const CalendarModal: React.FC<{
  workouts: WorkoutSession[];
  onClose: () => void;
}> = ({ workouts, onClose }) => {
  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/75 backdrop-blur-md p-0 sm:p-4">
      <div className="w-full max-w-md bg-[#161720] border border-white/10 rounded-t-3xl sm:rounded-3xl p-5 shadow-2xl animate-in slide-in-from-bottom">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="text-base font-bold text-white">Calendario Semanal</h3>
            <p className="text-xs text-neutral-400">Min Max Personal • Semana 5</p>
          </div>
          <button onClick={onClose} className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-neutral-300">✕</button>
        </div>
        <div className="space-y-2 mb-4">
          {workouts.map((w) => (
            <div key={w.id} className="p-3 rounded-xl bg-[#10121a] border border-white/5 flex items-center justify-between">
              <div>
                <span className="text-[11px] text-[#00E5FF] font-mono font-semibold">{w.dayLabel}</span>
                <div className="text-xs font-bold text-white">{w.name}</div>
              </div>
              <span className={`text-xs px-2 py-0.5 rounded-md ${w.completed ? 'bg-[#00E5FF]/20 text-[#00E5FF]' : 'bg-neutral-800 text-neutral-400'}`}>
                {w.completed ? 'Completado' : 'Programado'}
              </span>
            </div>
          ))}
          <div className="p-3 rounded-xl bg-[#10121a] border border-white/5 flex items-center justify-between">
            <div>
              <span className="text-[11px] text-indigo-400 font-mono font-semibold">Sa 17 & Su 18</span>
              <div className="text-xs font-bold text-white">Días de Descanso y Recuperación</div>
            </div>
            <span className="text-xs px-2 py-0.5 rounded-md bg-indigo-500/20 text-indigo-400">Descanso</span>
          </div>
        </div>
        <button
          onClick={onClose}
          className="w-full py-2.5 rounded-full bg-white/10 hover:bg-white/20 text-white font-semibold text-xs"
        >
          Cerrar
        </button>
      </div>
    </div>
  );
};
