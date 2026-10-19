import React from 'react';
import { TabType } from '../types';

interface BottomNavProps {
  activeTab: TabType;
  onSelectTab: (tab: TabType) => void;
  onOpenQuickLog: () => void;
}

export const BottomNav: React.FC<BottomNavProps> = ({
  activeTab,
  onSelectTab,
  onOpenQuickLog,
}) => {
  return (
    <nav className="fixed bottom-4 inset-x-0 z-50 px-4 flex justify-center pointer-events-none pb-safe">
      <div className="pointer-events-auto w-full max-w-md h-16 rounded-[28px] liquid-nav px-3 flex items-center justify-around shadow-2xl">
        {/* 1. Dashboard */}
        <button
          onClick={() => onSelectTab('dashboard')}
          className={`flex flex-col items-center justify-center py-1 px-2.5 transition-colors group relative ${
            activeTab === 'dashboard' ? 'text-white' : 'text-neutral-400 hover:text-white'
          }`}
          aria-label="Dashboard"
        >
          <svg
            className={`w-5 h-5 stroke-current transition-transform group-hover:scale-110 ${
              activeTab === 'dashboard' ? 'scale-105' : ''
            }`}
            fill="none"
            strokeWidth="2"
            viewBox="0 0 24 24"
          >
            <rect height="7" rx="2" width="7" x="3" y="3" />
            <rect height="7" rx="2" width="7" x="14" y="3" />
            <rect height="7" rx="2" width="7" x="14" y="14" />
            <rect height="7" rx="2" width="7" x="3" y="14" />
          </svg>
          <span className="text-[10px] font-medium mt-1">Dashboard</span>
          {activeTab === 'dashboard' && (
            <span className="w-1.5 h-1.5 rounded-full bg-white shadow-[0_0_8px_#ffffff] mt-0.5" />
          )}
        </button>

        {/* 2. Workout (Active electric cyan when selected) */}
        <button
          onClick={() => onSelectTab('workout')}
          className={`flex flex-col items-center justify-center py-1 px-2.5 transition-colors group relative ${
            activeTab === 'workout' ? 'text-[#00E5FF]' : 'text-neutral-400 hover:text-white'
          }`}
          aria-label="Workout"
        >
          <svg
            className="w-5 h-5 fill-current transform -rotate-45 transition-transform group-hover:scale-110"
            viewBox="0 0 24 24"
          >
            <path d="M6 5v14h3v-2h6v2h3V5h-3v2H9V5H6zm2 4h8v6H8V9z" />
          </svg>
          <span className="text-[10px] font-bold mt-1 tracking-tight">Workout</span>
          {activeTab === 'workout' && (
            <span className="w-1.5 h-1.5 rounded-full bg-[#00E5FF] shadow-[0_0_8px_#00E5FF] mt-0.5" />
          )}
        </button>

        {/* 3. Central Coral '+' Button */}
        <button
          onClick={onOpenQuickLog}
          aria-label="Nuevo Registro"
          className="w-12 h-12 -mt-5 rounded-full bg-[#FF5757] shadow-coral-glow flex items-center justify-center text-white transform active:scale-95 hover:brightness-110 transition-all cursor-pointer"
        >
          <svg className="w-6 h-6 stroke-white stroke-[2.5]" fill="none" viewBox="0 0 24 24">
            <path d="M12 4v16m8-8H4" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </button>

        {/* 4. Nutrición / Macros */}
        <button
          onClick={() => onSelectTab('nutrition')}
          className={`flex flex-col items-center justify-center py-1 px-2.5 transition-colors group relative ${
            activeTab === 'nutrition' ? 'text-[#FF8E53]' : 'text-neutral-400 hover:text-white'
          }`}
          aria-label="Nutrición"
        >
          <svg
            className="w-5 h-5 stroke-current group-hover:scale-110 transition-transform"
            fill="none"
            strokeWidth="2"
            viewBox="0 0 24 24"
          >
            <path
              d="M12 2a4 4 0 00-4 4c0 .34.04.67.11.98C5.28 7.6 3 10.3 3 13.5 3 17.64 6.36 21 10.5 21c2.14 0 4.09-.89 5.5-2.33 1.41 1.44 3.36 2.33 5.5 2.33 4.14 0 7.5-3.36 7.5-7.5 0-3.2-2.28-5.9-5.11-6.52.07-.31.11-.64.11-.98a4 4 0 00-4-4c-1.55 0-2.91.88-3.6 2.18-.32-.61-.79-1.12-1.37-1.49-.65-.43-1.42-.69-2.25-.69h-.28z"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          <span className="text-[10px] font-medium mt-1">Nutrición</span>
          {activeTab === 'nutrition' && (
            <span className="w-1.5 h-1.5 rounded-full bg-[#FF8E53] shadow-[0_0_8px_#FF8E53] mt-0.5" />
          )}
        </button>

        {/* 5. Perfil / Body */}
        <button
          onClick={() => onSelectTab('profile')}
          className={`flex flex-col items-center justify-center py-1 px-2.5 transition-colors group relative ${
            activeTab === 'profile' ? 'text-[#B388FF]' : 'text-neutral-400 hover:text-white'
          }`}
          aria-label="Perfil"
        >
          <svg
            className="w-5 h-5 stroke-current group-hover:scale-110 transition-transform"
            fill="none"
            strokeWidth="2"
            viewBox="0 0 24 24"
          >
            <path
              d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          <span className="text-[10px] font-medium mt-1">Perfil</span>
          {activeTab === 'profile' && (
            <span className="w-1.5 h-1.5 rounded-full bg-[#B388FF] shadow-[0_0_8px_#B388FF] mt-0.5" />
          )}
        </button>
      </div>
    </nav>
  );
};
