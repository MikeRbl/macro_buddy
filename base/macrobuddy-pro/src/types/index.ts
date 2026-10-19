export type TabType = 'dashboard' | 'workout' | 'nutrition' | 'profile';

export interface Exercise {
  id: string;
  name: string;
  sets: number;
  reps: string;
  targetWeightKg: number;
  completedSets?: boolean[];
  restSecs: number;
  muscle: string;
  notes?: string;
}

export interface WorkoutSession {
  id: string;
  name: string;
  title: string;
  description: string;
  muscleTags: string[];
  completed: boolean;
  dayIndex: number; // 0 for Mo, 1 for Tu, etc.
  dayLabel: string;
  durationMin: number;
  exercises: Exercise[];
}

export interface RestDay {
  id: string;
  title: string;
  subtitle: string;
  badgeText: string;
  badgeType: 'descanso' | 'recarga';
  iconType: 'moon' | 'smile';
  dayIndex: number;
  dayLabel: string;
}

export interface DayOption {
  dayNum: number;
  dayName: string;
  hasDot?: boolean;
}

export interface CoachPlan {
  coachName: string;
  coachTitle: string;
  coachInitials: string;
  connectionStatus: string;
  guidedModeActive: boolean;
  version: string;
  targetCalories: number;
  targetProtein: number;
  targetCarbs: number;
  targetFat: number;
  isLocked: boolean;
  protocolPhase: string;
  coachMessage: string;
  weeklyCheckinDay: string;
  lastUpdated: string;
}

export interface UserProfile {
  name: string;
  handle: string;
  avatarUrl: string;
  isPro: boolean;
  isVerified: boolean;
  currentWeight: number;
  weightChange: number;
  bodyFatPct: number;
  bodyFatMethod: string;
  streakDays: number;
  streakLevel: number;
  athleteId: string;
  appVersion: string;
  unitSystem: 'metric' | 'imperial';
  gymName: string;
  restTimerSeconds: number;
  healthSync: {
    appleHealth: boolean;
    strava: boolean;
    googleFit: boolean;
  };
}

export interface FoodItem {
  id: string;
  name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  portion: string;
}

export interface Meal {
  id: string;
  name: string;
  time: string;
  icon: string;
  items: FoodItem[];
}
