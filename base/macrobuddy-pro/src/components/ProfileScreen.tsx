import React from 'react';
import { UserProfile, CoachPlan } from '../types';

interface ProfileScreenProps {
  user: UserProfile;
  coachPlan: CoachPlan;
  onOpenCoachPlan: () => void;
  onOpenUnlinkCoach: () => void;
  onOpenUnitsModal: () => void;
  onOpenMacroTargetsModal: () => void;
  onOpenIntegrationsModal: () => void;
  onOpenGymEquipmentModal: () => void;
  onOpenTimerModal: () => void;
  onOpenExportModal: () => void;
  onOpenEditProfileModal: () => void;
  onLogout: () => void;
}

export const ProfileScreen: React.FC<ProfileScreenProps> = ({
  user,
  coachPlan,
  onOpenCoachPlan,
  onOpenUnlinkCoach,
  onOpenUnitsModal,
  onOpenMacroTargetsModal,
  onOpenIntegrationsModal,
  onOpenGymEquipmentModal,
  onOpenTimerModal,
  onOpenExportModal,
  onOpenEditProfileModal,
  onLogout,
}) => {
  return (
    <div className="bg-[#0A0A0A] text-white font-sans min-h-screen selection:bg-[#FF6B6B]/30 selection:text-white">
      {/* Top Header */}
      <header className="sticky top-0 inset-x-0 z-40 bg-[#121212]/80 backdrop-blur-2xl border-b border-white/5">
        <div className="max-w-md mx-auto h-16 px-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-[#FF6B6B] to-[#FF8E53] flex items-center justify-center shadow-sm">
              <svg className="w-4 h-4 text-black fill-current" viewBox="0 0 24 24">
                <path d="M11 21h-1l1-7H7.5c-.58 0-.57-.32-.38-.66.19-.34.05-.08.07-.12C8.48 10.94 10.42 7.54 13 3h1l-1 7h3.5c.49 0 .56.33.47.51l-.07.15C14.9 14.86 12.96 18.26 11 21z" />
              </svg>
            </div>
            <span className="text-lg font-semibold tracking-tight text-white">Macrobuddy</span>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-xs text-[#A0A0A0] uppercase tracking-wider font-medium">Profile</span>
            <button
              onClick={onOpenEditProfileModal}
              className="relative p-0.5 rounded-full ring-1 ring-white/10 hover:ring-[#FF6B6B] transition-all cursor-pointer"
            >
              <img
                alt="Profile"
                className="w-8 h-8 rounded-full object-cover"
                src={user.avatarUrl}
                referrerPolicy="no-referrer"
              />
            </button>
          </div>
        </div>
      </header>

      {/* Main Profile Content */}
      <main className="flex flex-col relative w-full pb-32 bg-[#0A0A0A] min-h-screen">
        <div className="max-w-md mx-auto w-full px-4 pt-4 pb-8 space-y-5">
          {/* Top Action Bar */}
          <div className="flex items-center justify-between pt-1">
            <div className="flex flex-col">
              <span className="text-[11px] text-[#FF6B6B] uppercase tracking-widest font-semibold">
                Configuración Personal
              </span>
              <h1 className="text-2xl text-white tracking-tight font-bold">Perfil & Ajustes</h1>
            </div>
            <div className="flex items-center gap-1.5">
              <button
                onClick={onOpenEditProfileModal}
                aria-label="Editar Perfil"
                className="w-10 h-10 rounded-full bg-[#2a2a2a]/80 backdrop-blur-xl flex items-center justify-center text-neutral-300 hover:text-white active:scale-95 transition-all shadow-sm cursor-pointer border border-white/5"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="1.8"
                  />
                </svg>
              </button>
              <button
                onClick={onOpenMacroTargetsModal}
                aria-label="Ajustes Generales"
                className="w-10 h-10 rounded-full bg-[#2a2a2a]/80 backdrop-blur-xl flex items-center justify-center text-neutral-300 hover:text-white active:scale-95 transition-all shadow-sm cursor-pointer border border-white/5"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="1.8"
                  />
                  <path
                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="1.8"
                  />
                </svg>
              </button>
            </div>
          </div>

          {/* User Identity Card */}
          <div className="relative overflow-hidden rounded-3xl bg-[#201f1f]/70 backdrop-blur-2xl p-5 shadow-xl border border-white/5">
            <div className="absolute -top-16 -right-16 w-44 h-44 rounded-full bg-[#FF6B6B]/10 blur-3xl pointer-events-none" />
            <div className="flex items-center gap-4 relative z-10">
              <div className="relative shrink-0">
                <div className="w-20 h-20 rounded-full p-1 bg-gradient-to-tr from-[#FF6B6B] via-[#FF8E53] to-[#B388FF] shadow-lg">
                  <img
                    alt="Carlos Mendoza Avatar"
                    className="w-full h-full rounded-full object-cover"
                    src={user.avatarUrl}
                    referrerPolicy="no-referrer"
                  />
                </div>
                <div className="absolute bottom-0 right-0 w-6 h-6 rounded-full bg-[#0A0A0A] flex items-center justify-center">
                  <div className="w-4 h-4 rounded-full bg-[#00daf3] shadow-[0_0_8px_#00daf3]" />
                </div>
              </div>

              <div className="flex flex-col min-w-0">
                <div className="flex items-center gap-1.5 flex-wrap">
                  <h2 className="text-lg text-white truncate font-bold">{user.name}</h2>
                  <span className="inline-flex items-center gap-0.5 px-2.5 py-0.5 rounded-full bg-[#FF6B6B]/15 text-[#FF6B6B] text-[11px] font-semibold tracking-wide shadow-sm">
                    PRO ⚡
                  </span>
                </div>
                <span className="text-[13px] text-[#A0A0A0]">{user.handle}</span>
                <div className="flex items-center gap-1.5 mt-1 text-[#00E5FF]">
                  <svg className="w-4 h-4 fill-current" viewBox="0 0 24 24">
                    <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z" />
                  </svg>
                  <span className="text-[11px] font-medium">Atleta Verificado Macrobuddy</span>
                </div>
              </div>
            </div>

            {/* Quick Metrics Strip */}
            <div className="grid grid-cols-3 gap-1 mt-4 pt-3 bg-[#0e0e0e]/70 rounded-2xl p-3 border border-white/5">
              <div className="flex flex-col items-center text-center">
                <span className="text-[11px] text-[#A0A0A0] uppercase font-medium">Peso Actual</span>
                <span className="font-mono text-lg text-white font-bold mt-0.5 tabular-nums">
                  {user.currentWeight}{' '}
                  <span className="text-xs font-normal text-[#A0A0A0]">
                    {user.unitSystem === 'metric' ? 'kg' : 'lbs'}
                  </span>
                </span>
                <div className="flex items-center gap-0.5 mt-0.5 text-[#00E5FF]">
                  <svg className="w-3.5 h-3.5 fill-none stroke-current" viewBox="0 0 24 24">
                    <path
                      d="M13 17l5-5-5-5M6 17l5-5-5-5"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                    />
                  </svg>
                  <span className="text-[11px] font-semibold">
                    {user.weightChange > 0 ? `+${user.weightChange}` : user.weightChange} kg
                  </span>
                </div>
              </div>

              <div className="flex flex-col items-center text-center">
                <span className="text-[11px] text-[#A0A0A0] uppercase font-medium">Grasa Est.</span>
                <span className="font-mono text-lg text-white font-bold mt-0.5 tabular-nums">
                  {user.bodyFatPct}
                  <span className="text-xs font-normal text-[#A0A0A0]">%</span>
                </span>
                <span className="text-[11px] text-[#A0A0A0] mt-0.5">{user.bodyFatMethod}</span>
              </div>

              <div className="flex flex-col items-center text-center">
                <span className="text-[11px] text-[#A0A0A0] uppercase font-medium">Racha Activa</span>
                <span className="font-mono text-lg text-[#FF8E53] font-bold mt-0.5 tabular-nums">
                  {user.streakDays}{' '}
                  <span className="text-xs font-normal text-[#A0A0A0]">días</span>
                </span>
                <div className="flex items-center gap-0.5 mt-0.5 text-[#FF6B6B]">
                  <svg className="w-3.5 h-3.5 fill-current" viewBox="0 0 24 24">
                    <path d="M13.5.67s.74 2.65.74 4.8c0 2.06-1.35 3.73-3.41 3.73-2.07 0-3.63-1.67-3.63-3.73l.03-.36C5.21 7.51 4 10.61 4 14c0 4.42 3.58 8 8 8s8-3.58 8-8C20 8.61 17.41 3.8 13.5.67zM11.71 19c-1.78 0-3.22-1.4-3.22-3.14 0-1.62 1.05-2.76 2.81-3.12 1.77-.36 3.6-1.21 4.62-2.58.39 1.29.59 2.65.59 4.04 0 2.65-2.15 4.8-4.8 4.8z" />
                  </svg>
                  <span className="text-[11px] font-semibold">Nivel {user.streakLevel}</span>
                </div>
              </div>
            </div>
          </div>

          {/* KEY HERO SECTION: Mi Entrenador / Professional Link */}
          <div className="relative overflow-hidden rounded-3xl bg-[#2a2a2a]/90 backdrop-blur-2xl p-5 shadow-2xl border border-white/5">
            {/* Ambient Violet/Indigo Glow Layer */}
            <div className="absolute -top-12 -left-12 w-48 h-48 rounded-full bg-[#B388FF]/15 blur-3xl pointer-events-none" />
            <div className="absolute -bottom-16 -right-16 w-52 h-52 rounded-full bg-[#b085fc]/20 blur-3xl pointer-events-none" />

            {/* Header & Badge */}
            <div className="flex items-center justify-between relative z-10 mb-4">
              <div className="flex items-center gap-2">
                <div className="w-9 h-9 rounded-xl bg-[#B388FF]/20 flex items-center justify-center text-[#B388FF] shadow-sm">
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="1.8"
                    />
                  </svg>
                </div>
                <div className="flex flex-col">
                  <span className="text-base text-white font-semibold">Mi Entrenador</span>
                  <span className="text-[11px] text-[#d4bbff]">
                    Professional Link {coachPlan.version}
                  </span>
                </div>
              </div>

              {coachPlan.guidedModeActive ? (
                <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#B388FF]/20 shadow-[0_0_12px_rgba(179,136,255,0.35)]">
                  <span className="w-2 h-2 rounded-full bg-[#B388FF] animate-ping" />
                  <span className="text-[11px] text-[#B388FF] font-semibold uppercase tracking-wider">
                    Modo Guiado Activo
                  </span>
                </div>
              ) : (
                <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-neutral-800 text-neutral-400">
                  <span className="text-[11px] font-semibold uppercase tracking-wider">
                    Modo Libre
                  </span>
                </div>
              )}
            </div>

            {/* Coach Identity Tile */}
            <div className="relative z-10 flex items-center gap-3.5 p-3.5 rounded-2xl bg-[#0e0e0e]/80 backdrop-blur-md mb-4 border border-white/5">
              <div className="relative shrink-0">
                <div className="w-12 h-12 rounded-full bg-[#353534] flex items-center justify-center text-white text-base font-bold shadow-md">
                  {coachPlan.coachInitials}
                </div>
                <span className="absolute bottom-0 right-0 w-3.5 h-3.5 rounded-full bg-[#00daf3] shadow-[0_0_6px_#00daf3]" />
              </div>
              <div className="flex flex-col min-w-0">
                <div className="flex items-center gap-1.5">
                  <span className="text-[11px] text-[#A0A0A0]">Vinculado con</span>
                  <span className="text-[11px] text-[#9cf0ff] font-medium">
                    ● {coachPlan.connectionStatus}
                  </span>
                </div>
                <h3 className="text-base text-white font-bold truncate">{coachPlan.coachName}</h3>
                <p className="text-[11px] text-[#A0A0A0] truncate">{coachPlan.coachTitle}</p>
              </div>
            </div>

            {/* Informative Callout Text */}
            <div className="relative z-10 p-3.5 rounded-2xl bg-[#1c1b1b]/90 mb-4 flex gap-2.5 items-start border border-white/5">
              <svg
                className="w-5 h-5 text-[#FF8E53] shrink-0 mt-0.5 fill-none stroke-current"
                viewBox="0 0 24 24"
              >
                <path
                  d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2"
                />
              </svg>
              <div className="flex flex-col">
                <p className="text-sm text-white leading-snug">
                  Tus macros y rutinas están siendo gestionados por tu entrenador. La edición manual
                  está bloqueada.
                </p>
                {/* Lock Macro Indicators */}
                <div className="flex items-center gap-2 flex-wrap mt-2.5">
                  <div className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-[#353534]/90 text-white font-mono text-xs font-medium">
                    <span>Calorías {coachPlan.targetCalories.toLocaleString()} kcal</span>
                    <span className="text-[#FF8E53] text-xs">🔒</span>
                  </div>
                  <div className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-[#353534]/90 text-white font-mono text-xs font-medium">
                    <span>Proteína {coachPlan.targetProtein}g</span>
                    <span className="text-[#FF8E53] text-xs">🔒</span>
                  </div>
                  <div className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-[#353534]/90 text-white font-mono text-xs font-medium">
                    <span>Carbs {coachPlan.targetCarbs}g</span>
                    <span className="text-[#FF8E53] text-xs">🔒</span>
                  </div>
                </div>
              </div>
            </div>

            {/* Coach Action Buttons */}
            <div className="relative z-10 flex items-center gap-2">
              <button
                onClick={onOpenCoachPlan}
                className="flex-1 py-3 px-4 rounded-full bg-gradient-to-r from-[#B388FF] to-[#b085fc] text-black text-sm font-semibold flex items-center justify-center gap-2 active:scale-95 transition-all shadow-[0_0_16px_rgba(179,136,255,0.4)] cursor-pointer"
              >
                <svg className="w-5 h-5 fill-none stroke-current" viewBox="0 0 24 24">
                  <path
                    d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                  />
                </svg>
                <span>Ver plan asignado</span>
              </button>
              <button
                onClick={onOpenUnlinkCoach}
                className="py-3 px-4 rounded-full bg-[#353534]/60 hover:bg-[#353534] text-[#ffb4ab] text-sm font-medium active:scale-95 transition-all flex items-center justify-center cursor-pointer"
              >
                <span>{coachPlan.guidedModeActive ? 'Desvincular' : 'Reconectar'}</span>
              </button>
            </div>
          </div>

          {/* Settings Category: Cuenta & Preferencias */}
          <div className="flex flex-col gap-1.5">
            <div className="flex items-center justify-between px-1">
              <span className="text-[11px] text-[#A0A0A0] uppercase tracking-wider font-semibold">
                Cuenta & Preferencias
              </span>
            </div>
            <div className="flex flex-col rounded-3xl bg-[#201f1f]/60 backdrop-blur-xl p-1 shadow-lg border border-white/5">
              {/* Item 1: Unidades */}
              <button
                onClick={onOpenUnitsModal}
                className="flex items-center justify-between p-3.5 rounded-2xl hover:bg-[#2a2a2a]/60 active:bg-[#2a2a2a] transition-colors text-left w-full cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0">
                  <div className="w-10 h-10 rounded-xl bg-[#353534] flex items-center justify-center text-white shrink-0">
                    <svg className="w-5 h-5 fill-none stroke-current" viewBox="0 0 24 24">
                      <path
                        d="M3 6h18M3 12h18M3 18h18"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth="2"
                      />
                    </svg>
                  </div>
                  <div className="flex flex-col min-w-0">
                    <span className="text-base text-white font-medium">Unidades de Medida</span>
                    <span className="text-xs text-[#A0A0A0]">
                      {user.unitSystem === 'metric' ? 'Métrico (kg, cm, kcal)' : 'Imperial (lbs, in, kcal)'}
                    </span>
                  </div>
                </div>
                <svg className="w-5 h-5 text-[#A0A0A0] shrink-0 fill-none stroke-current" viewBox="0 0 24 24">
                  <path d="M9 5l7 7-7 7" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" />
                </svg>
              </button>

              {/* Item 2: Objetivos (Locked) */}
              <button
                onClick={onOpenMacroTargetsModal}
                className="flex items-center justify-between p-3.5 rounded-2xl hover:bg-[#2a2a2a]/60 active:bg-[#2a2a2a] transition-colors text-left w-full cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0">
                  <div className="w-10 h-10 rounded-xl bg-[#353534] flex items-center justify-center text-[#FF8E53] shrink-0">
                    <svg className="w-5 h-5 fill-none stroke-current" viewBox="0 0 24 24">
                      <path
                        d="M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth="2"
                      />
                      <path
                        d="M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth="2"
                      />
                    </svg>
                  </div>
                  <div className="flex flex-col min-w-0">
                    <span className="text-base text-white font-medium">
                      Objetivos Calóricos & Macros
                    </span>
                    <div className="flex items-center gap-1">
                      <span className="text-xs text-[#B388FF] font-medium">
                        Gestionado por Entrenador
                      </span>
                      <span className="text-xs text-[#FF8E53]">🔒</span>
                    </div>
                  </div>
                </div>
                <svg className="w-5 h-5 text-[#A0A0A0] shrink-0 fill-none stroke-current" viewBox="0 0 24 24">
                  <path d="M9 5l7 7-7 7" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" />
                </svg>
              </button>

              {/* Item 3: Integraciones */}
              <button
                onClick={onOpenIntegrationsModal}
                className="flex items-center justify-between p-3.5 rounded-2xl hover:bg-[#2a2a2a]/60 active:bg-[#2a2a2a] transition-colors text-left w-full cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0">
                  <div className="w-10 h-10 rounded-xl bg-[#353534] flex items-center justify-center text-[#00E5FF] shrink-0">
                    <svg className="w-5 h-5 fill-none stroke-current" viewBox="0 0 24 24">
                      <path
                        d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth="2"
                      />
                    </svg>
                  </div>
                  <div className="flex flex-col min-w-0">
                    <span className="text-base text-white font-medium">Integraciones de Salud</span>
                    <span className="text-xs text-[#A0A0A0]">Apple Health & Strava (Conectado)</span>
                  </div>
                </div>
                <svg className="w-5 h-5 text-[#A0A0A0] shrink-0 fill-none stroke-current" viewBox="0 0 24 24">
                  <path d="M9 5l7 7-7 7" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" />
                </svg>
              </button>
            </div>
          </div>

          {/* Settings Category: Entrenamiento & Dispositivos */}
          <div className="flex flex-col gap-1.5">
            <div className="flex items-center justify-between px-1">
              <span className="text-[11px] text-[#A0A0A0] uppercase tracking-wider font-semibold">
                Entrenamiento & Dispositivos
              </span>
            </div>
            <div className="flex flex-col rounded-3xl bg-[#201f1f]/60 backdrop-blur-xl p-1 shadow-lg border border-white/5">
              {/* Item 1: Gimnasio */}
              <button
                onClick={onOpenGymEquipmentModal}
                className="flex items-center justify-between p-3.5 rounded-2xl hover:bg-[#2a2a2a]/60 active:bg-[#2a2a2a] transition-colors text-left w-full cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0">
                  <div className="w-10 h-10 rounded-xl bg-[#353534] flex items-center justify-center text-[#FF6B6B] shrink-0">
                    <svg className="w-5 h-5 fill-none stroke-current" viewBox="0 0 24 24">
                      <path
                        d="M4 6h2v12H4zm14 0h2v12h-2zm-6-2h2v16h-2z"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth="2"
                      />
                    </svg>
                  </div>
                  <div className="flex flex-col min-w-0">
                    <span className="text-base text-white font-medium">Equipo & Gimnasio</span>
                    <span className="text-xs text-[#A0A0A0]">{user.gymName}</span>
                  </div>
                </div>
                <svg className="w-5 h-5 text-[#A0A0A0] shrink-0 fill-none stroke-current" viewBox="0 0 24 24">
                  <path d="M9 5l7 7-7 7" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" />
                </svg>
              </button>

              {/* Item 2: Temporizador */}
              <button
                onClick={onOpenTimerModal}
                className="flex items-center justify-between p-3.5 rounded-2xl hover:bg-[#2a2a2a]/60 active:bg-[#2a2a2a] transition-colors text-left w-full cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0">
                  <div className="w-10 h-10 rounded-xl bg-[#353534] flex items-center justify-center text-[#bdf4ff] shrink-0">
                    <svg className="w-5 h-5 fill-none stroke-current" viewBox="0 0 24 24">
                      <path
                        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth="2"
                      />
                    </svg>
                  </div>
                  <div className="flex flex-col min-w-0">
                    <span className="text-base text-white font-medium">Temporizador de Descanso</span>
                    <span className="text-xs text-[#A0A0A0]">
                      Auto Inteligente ({user.restTimerSeconds}s)
                    </span>
                  </div>
                </div>
                <svg className="w-5 h-5 text-[#A0A0A0] shrink-0 fill-none stroke-current" viewBox="0 0 24 24">
                  <path d="M9 5l7 7-7 7" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" />
                </svg>
              </button>
            </div>
          </div>

          {/* Settings Category: Soporte & Privacidad */}
          <div className="flex flex-col gap-1.5">
            <div className="flex items-center justify-between px-1">
              <span className="text-[11px] text-[#A0A0A0] uppercase tracking-wider font-semibold">
                Soporte & Privacidad
              </span>
            </div>
            <div className="flex flex-col rounded-3xl bg-[#201f1f]/60 backdrop-blur-xl p-1 shadow-lg border border-white/5">
              <button
                onClick={onOpenExportModal}
                className="flex items-center justify-between w-full p-3.5 rounded-2xl hover:bg-[#2a2a2a]/60 active:bg-[#2a2a2a] transition-colors text-left cursor-pointer"
              >
                <div className="flex items-center gap-3.5">
                  <div className="w-10 h-10 rounded-xl bg-[#353534] flex items-center justify-center text-white shrink-0">
                    <svg className="w-5 h-5 fill-none stroke-current" viewBox="0 0 24 24">
                      <path
                        d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth="2"
                      />
                    </svg>
                  </div>
                  <span className="text-base text-white font-medium">
                    Exportar Datos de Rendimiento
                  </span>
                </div>
                <svg className="w-5 h-5 text-[#A0A0A0] fill-none stroke-current" viewBox="0 0 24 24">
                  <path d="M9 5l7 7-7 7" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" />
                </svg>
              </button>

              <button
                onClick={onLogout}
                className="flex items-center justify-between w-full p-3.5 rounded-2xl hover:bg-[#93000a]/20 active:bg-[#93000a]/30 transition-colors text-left cursor-pointer"
              >
                <div className="flex items-center gap-3.5">
                  <div className="w-10 h-10 rounded-xl bg-[#93000a]/30 flex items-center justify-center text-[#ffb4ab] shrink-0">
                    <svg className="w-5 h-5 fill-none stroke-current" viewBox="0 0 24 24">
                      <path
                        d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth="2"
                      />
                    </svg>
                  </div>
                  <span className="text-base text-[#ffb4ab] font-medium">Cerrar Sesión</span>
                </div>
              </button>
            </div>
          </div>

          {/* App Info Footer Stamp */}
          <div className="flex flex-col items-center justify-center pt-2 pb-6 text-center">
            <span className="text-[11px] text-[#A0A0A0]/70">{user.appVersion}</span>
            <span className="text-[11px] text-[#A0A0A0]/50 mt-0.5">ID Atleta: {user.athleteId}</span>
          </div>
        </div>
      </main>
    </div>
  );
};
