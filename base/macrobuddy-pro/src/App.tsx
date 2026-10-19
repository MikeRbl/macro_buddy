import { useState } from 'react';
import { TabType, WorkoutSession, UserProfile, CoachPlan, Meal, FoodItem } from './types';
import {
  DAYS_CAROUSEL,
  INITIAL_WORKOUTS,
  REST_DAYS,
  INITIAL_USER,
  INITIAL_COACH_PLAN,
  INITIAL_MEALS,
} from './data/mockData';
import { WorkoutScreen } from './components/WorkoutScreen';
import { ProfileScreen } from './components/ProfileScreen';
import { DashboardScreen } from './components/DashboardScreen';
import { NutritionScreen } from './components/NutritionScreen';
import { BottomNav } from './components/BottomNav';
import { WorkoutDetailModal } from './components/WorkoutDetailModal';
import { CoachPlanModal } from './components/CoachPlanModal';
import { QuickLogModal } from './components/QuickLogModal';
import {
  UnitsModal,
  IntegrationsModal,
  RestTimerModal,
  GymEquipmentModal,
  ExportModal,
  EditProfileModal,
  UnlinkCoachModal,
  CalendarModal,
} from './components/SettingsModals';

export default function App() {
  // Navigation & state
  const [activeTab, setActiveTab] = useState<TabType>('workout');
  const [selectedDayNum, setSelectedDayNum] = useState<number>(12);
  const [workouts, setWorkouts] = useState<WorkoutSession[]>(INITIAL_WORKOUTS);
  const [restDays] = useState(REST_DAYS);
  const [user, setUser] = useState<UserProfile>(INITIAL_USER);
  const [coachPlan, setCoachPlan] = useState<CoachPlan>(INITIAL_COACH_PLAN);
  const [meals, setMeals] = useState<Meal[]>(INITIAL_MEALS);

  // Modals state
  const [activeWorkoutDetail, setActiveWorkoutDetail] = useState<WorkoutSession | null>(null);
  const [showCoachPlanModal, setShowCoachPlanModal] = useState<boolean>(false);
  const [showQuickLogModal, setShowQuickLogModal] = useState<boolean>(false);
  const [showUnitsModal, setShowUnitsModal] = useState<boolean>(false);
  const [showIntegrationsModal, setShowIntegrationsModal] = useState<boolean>(false);
  const [showTimerModal, setShowTimerModal] = useState<boolean>(false);
  const [showGymEquipmentModal, setShowGymEquipmentModal] = useState<boolean>(false);
  const [showExportModal, setShowExportModal] = useState<boolean>(false);
  const [showEditProfileModal, setShowEditProfileModal] = useState<boolean>(false);
  const [showUnlinkCoachModal, setShowUnlinkCoachModal] = useState<boolean>(false);
  const [showCalendarModal, setShowCalendarModal] = useState<boolean>(false);

  // Toast feedback
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3200);
  };

  // Handlers
  const handleToggleWorkoutCompleted = (workoutId: string) => {
    setWorkouts((prev) =>
      prev.map((w) => {
        if (w.id === workoutId) {
          const nextState = !w.completed;
          showToast(nextState ? `✓ ¡${w.name} marcado como completado!` : `${w.name} desmarcado`);
          return { ...w, completed: nextState };
        }
        return w;
      })
    );
  };

  const handleCompleteWorkoutFromModal = (workoutId: string) => {
    setWorkouts((prev) =>
      prev.map((w) => (w.id === workoutId ? { ...w, completed: true } : w))
    );
    setUser((prev) => ({
      ...prev,
      streakDays: prev.streakDays + 1,
    }));
    showToast('🔥 ¡Gran entrenamiento! Sesión registrada y racha actualizada');
  };

  const handleLogWeight = (newWeight: number) => {
    const diff = +(newWeight - user.currentWeight).toFixed(1);
    setUser((prev) => ({
      ...prev,
      currentWeight: newWeight,
      weightChange: diff,
    }));
    showToast(`Peso actualizado: ${newWeight} kg (${diff > 0 ? '+' : ''}${diff} kg)`);
  };

  const handleAddQuickMeal = (name: string, cal: number, p: number, c: number, f: number) => {
    const newItem: FoodItem = {
      id: `f-${Date.now()}`,
      name,
      calories: cal,
      protein: p,
      carbs: c,
      fat: f,
      portion: '1 porción',
    };
    setMeals((prev) => {
      const copy = [...prev];
      if (copy[1]) {
        copy[1] = { ...copy[1], items: [...copy[1].items, newItem] };
      }
      return copy;
    });
    showToast(`✓ Alimento añadido: ${name} (${cal} kcal)`);
  };

  const handleAddFoodToMeal = (mealId: string, itemData: Omit<FoodItem, 'id'>) => {
    const newItem: FoodItem = {
      ...itemData,
      id: `food-${Date.now()}`,
    };
    setMeals((prev) =>
      prev.map((m) => (m.id === mealId ? { ...m, items: [...m.items, newItem] } : m))
    );
    showToast(`✓ Añadido a comida: ${newItem.name}`);
  };

  const handleDeleteFoodItem = (mealId: string, itemId: string) => {
    setMeals((prev) =>
      prev.map((m) =>
        m.id === mealId ? { ...m, items: m.items.filter((i) => i.id !== itemId) } : m
      )
    );
    showToast('Alimento eliminado');
  };

  const handleToggleGuidedCoach = () => {
    setCoachPlan((prev) => {
      const nextGuided = !prev.guidedModeActive;
      showToast(
        nextGuided
          ? '✓ Modo Guiado reactivado con Nutriólogo Juan Pérez'
          : 'Modo libre activado. Edición manual de macros permitida.'
      );
      return { ...prev, guidedModeActive: nextGuided, isLocked: nextGuided };
    });
  };

  return (
    <div className="bg-[#0A0B0E] text-white min-h-screen relative font-sans flex flex-col justify-between selection:bg-[#00E5FF] selection:text-black">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed top-4 inset-x-0 z-50 flex justify-center pointer-events-none px-4 animate-in fade-in slide-in-from-top duration-300">
          <div className="bg-[#1f222d] border border-[#00E5FF]/40 text-white text-xs font-semibold px-4 py-2.5 rounded-full shadow-teal-glow pointer-events-auto">
            {toastMessage}
          </div>
        </div>
      )}

      {/* Screen Render based on activeTab */}
      <div className="flex-1 w-full">
        {activeTab === 'workout' && (
          <WorkoutScreen
            workouts={workouts}
            restDays={restDays}
            carouselDays={DAYS_CAROUSEL}
            selectedDayNum={selectedDayNum}
            onSelectDay={(dayNum) => setSelectedDayNum(dayNum)}
            onToggleWorkoutCompleted={handleToggleWorkoutCompleted}
            onOpenWorkoutDetail={(w) => setActiveWorkoutDetail(w)}
            onOpenCalendarModal={() => setShowCalendarModal(true)}
            onOpenAddWorkoutModal={() => {
              // Add a quick extra workout
              const newW: WorkoutSession = {
                id: `workout-${Date.now()}`,
                name: `Workout ${String.fromCharCode(65 + workouts.length)}`,
                title: `Workout ${String.fromCharCode(65 + workouts.length)}`,
                description: 'Press banca plano, Curl martillo, Elevaciones laterales, Fondos...',
                muscleTags: ['Pecho', 'Tríceps', 'Hombros'],
                completed: false,
                dayIndex: workouts.length,
                dayLabel: 'Custom',
                durationMin: 50,
                exercises: [
                  {
                    id: `ex-new-1`,
                    name: 'Press de Banca Plano con Barra',
                    sets: 3,
                    reps: '8-10',
                    targetWeightKg: 80,
                    restSecs: 90,
                    muscle: 'Pecho',
                  },
                ],
              };
              setWorkouts((prev) => [...prev, newW]);
              showToast(`✓ Añadido nuevo ${newW.name}`);
            }}
          />
        )}

        {activeTab === 'profile' && (
          <ProfileScreen
            user={user}
            coachPlan={coachPlan}
            onOpenCoachPlan={() => setShowCoachPlanModal(true)}
            onOpenUnlinkCoach={() => setShowUnlinkCoachModal(true)}
            onOpenUnitsModal={() => setShowUnitsModal(true)}
            onOpenMacroTargetsModal={() => setShowCoachPlanModal(true)}
            onOpenIntegrationsModal={() => setShowIntegrationsModal(true)}
            onOpenGymEquipmentModal={() => setShowGymEquipmentModal(true)}
            onOpenTimerModal={() => setShowTimerModal(true)}
            onOpenExportModal={() => setShowExportModal(true)}
            onOpenEditProfileModal={() => setShowEditProfileModal(true)}
            onLogout={() => showToast('Sesión cerrada (Modo demostración)')}
          />
        )}

        {activeTab === 'dashboard' && (
          <DashboardScreen
            user={user}
            coachPlan={coachPlan}
            workouts={workouts}
            onStartTodayWorkout={(w) => setActiveWorkoutDetail(w)}
            onNavigateToWorkout={() => setActiveTab('workout')}
            onNavigateToNutrition={() => setActiveTab('nutrition')}
            onNavigateToProfile={() => setActiveTab('profile')}
          />
        )}

        {activeTab === 'nutrition' && (
          <NutritionScreen
            coachPlan={coachPlan}
            meals={meals}
            onAddFoodItem={handleAddFoodToMeal}
            onDeleteFoodItem={handleDeleteFoodItem}
            onOpenCoachPlan={() => setShowCoachPlanModal(true)}
          />
        )}
      </div>

      {/* Floating Bottom Navigation Bar */}
      <BottomNav
        activeTab={activeTab}
        onSelectTab={(t) => setActiveTab(t)}
        onOpenQuickLog={() => setShowQuickLogModal(true)}
      />

      {/* Modals */}
      {activeWorkoutDetail && (
        <WorkoutDetailModal
          workout={activeWorkoutDetail}
          defaultTimerSecs={user.restTimerSeconds}
          onClose={() => setActiveWorkoutDetail(null)}
          onCompleteWorkout={handleCompleteWorkoutFromModal}
        />
      )}

      {showCoachPlanModal && (
        <CoachPlanModal
          coachPlan={coachPlan}
          onClose={() => setShowCoachPlanModal(false)}
          onSendMessage={(msg) => {
            showToast(`Mensaje enviado a ${coachPlan.coachName}: "${msg}"`);
          }}
        />
      )}

      {showQuickLogModal && (
        <QuickLogModal
          currentWeight={user.currentWeight}
          unit={user.unitSystem === 'metric' ? 'kg' : 'lbs'}
          onClose={() => setShowQuickLogModal(false)}
          onLogWeight={handleLogWeight}
          onLogMeal={handleAddQuickMeal}
          onStartQuickTimer={() => {
            setShowTimerModal(true);
          }}
          onOpenWorkoutsTab={() => setActiveTab('workout')}
        />
      )}

      {showUnitsModal && (
        <UnitsModal
          currentSystem={user.unitSystem}
          onSave={(val) => {
            setUser((prev) => ({ ...prev, unitSystem: val }));
            showToast(`Unidades cambiadas a ${val === 'metric' ? 'Métrico' : 'Imperial'}`);
          }}
          onClose={() => setShowUnitsModal(false)}
        />
      )}

      {showIntegrationsModal && (
        <IntegrationsModal
          healthSync={user.healthSync}
          onSave={(sync) => {
            setUser((prev) => ({ ...prev, healthSync: sync }));
            showToast('Integraciones de salud actualizadas');
          }}
          onClose={() => setShowIntegrationsModal(false)}
        />
      )}

      {showTimerModal && (
        <RestTimerModal
          currentSeconds={user.restTimerSeconds}
          onSave={(secs) => {
            setUser((prev) => ({ ...prev, restTimerSeconds: secs }));
            showToast(`Temporizador configurado a ${secs} segundos`);
          }}
          onClose={() => setShowTimerModal(false)}
        />
      )}

      {showGymEquipmentModal && (
        <GymEquipmentModal
          gymName={user.gymName}
          onSave={(name) => {
            setUser((prev) => ({ ...prev, gymName: name }));
            showToast(`Centro de entrenamiento guardado: ${name}`);
          }}
          onClose={() => setShowGymEquipmentModal(false)}
        />
      )}

      {showExportModal && (
        <ExportModal
          user={user}
          coachPlan={coachPlan}
          workouts={workouts}
          onClose={() => setShowExportModal(false)}
        />
      )}

      {showEditProfileModal && (
        <EditProfileModal
          user={user}
          onSave={(name, handle, weight) => {
            setUser((prev) => ({
              ...prev,
              name,
              handle,
              currentWeight: weight,
            }));
            showToast('Perfil actualizado con éxito');
          }}
          onClose={() => setShowEditProfileModal(false)}
        />
      )}

      {showUnlinkCoachModal && (
        <UnlinkCoachModal
          coachName={coachPlan.coachName}
          isGuided={coachPlan.guidedModeActive}
          onToggle={handleToggleGuidedCoach}
          onClose={() => setShowUnlinkCoachModal(false)}
        />
      )}

      {showCalendarModal && (
        <CalendarModal workouts={workouts} onClose={() => setShowCalendarModal(false)} />
      )}
    </div>
  );
}
