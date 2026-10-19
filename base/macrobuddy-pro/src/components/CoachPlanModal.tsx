import React, { useState } from 'react';
import { CoachPlan } from '../types';

interface CoachPlanModalProps {
  coachPlan: CoachPlan;
  onClose: () => void;
  onSendMessage: (msg: string) => void;
}

export const CoachPlanModal: React.FC<CoachPlanModalProps> = ({
  coachPlan,
  onClose,
  onSendMessage,
}) => {
  const [chatInput, setChatInput] = useState('');
  const [messageSent, setMessageSent] = useState(false);

  const handleSend = (e: React.FormEvent) => {
    e.preventDefault();
    if (!chatInput.trim()) return;
    onSendMessage(chatInput.trim());
    setChatInput('');
    setMessageSent(true);
    setTimeout(() => setMessageSent(false), 3000);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/75 backdrop-blur-md p-0 sm:p-4">
      <div className="w-full max-w-lg max-h-[90vh] bg-[#14151b] border border-white/10 rounded-t-3xl sm:rounded-3xl flex flex-col overflow-hidden shadow-2xl animate-in slide-in-from-bottom duration-200">
        {/* Header */}
        <div className="p-5 pb-4 border-b border-white/10 flex items-start justify-between bg-gradient-to-r from-[#201533] to-[#171924]">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-2xl bg-[#B388FF]/20 border border-[#B388FF]/30 flex items-center justify-center text-[#B388FF] text-xl font-bold shadow-lg">
              {coachPlan.coachInitials}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-lg font-bold text-white">{coachPlan.coachName}</h2>
                <span className="text-[10px] font-bold text-[#00daf3] bg-[#00daf3]/10 px-2 py-0.5 rounded-full">
                  Verificado
                </span>
              </div>
              <p className="text-xs text-[#d4bbff]">{coachPlan.coachTitle}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-9 h-9 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-neutral-300 hover:text-white transition cursor-pointer"
          >
            ✕
          </button>
        </div>

        {/* Plan Body */}
        <div className="p-5 overflow-y-auto space-y-4 no-scrollbar flex-1">
          {/* Phase Banner */}
          <div className="p-4 rounded-2xl bg-[#1c1d27] border border-[#B388FF]/25 shadow-purple-glow">
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-bold uppercase tracking-wider text-[#B388FF]">
                Protocolo Activo
              </span>
              <span className="text-[11px] text-neutral-400">Actualizado: {coachPlan.lastUpdated}</span>
            </div>
            <h3 className="text-base font-bold text-white mt-1">{coachPlan.protocolPhase}</h3>
            <p className="text-xs text-neutral-300 mt-2 leading-relaxed bg-[#10121a] p-3 rounded-xl border border-white/5">
              "{coachPlan.coachMessage}"
            </p>
          </div>

          {/* Locked Macro Prescription */}
          <div className="p-4 rounded-2xl bg-[#1c1d27] border border-white/5 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold text-neutral-300 uppercase tracking-wider">
                Prescripción Calórica & Macros
              </span>
              <span className="text-xs font-mono text-[#FF8E53] flex items-center gap-1">
                <span>Gestión bloqueada</span>
                <span>🔒</span>
              </span>
            </div>

            <div className="grid grid-cols-4 gap-2">
              <div className="bg-[#10121a] p-2.5 rounded-xl border border-white/5 text-center">
                <span className="text-[10px] text-neutral-400 uppercase font-medium">Calorías</span>
                <div className="text-base font-bold text-white font-mono mt-0.5">
                  {coachPlan.targetCalories.toLocaleString()}
                </div>
                <span className="text-[10px] text-neutral-500">kcal/día</span>
              </div>
              <div className="bg-[#10121a] p-2.5 rounded-xl border border-white/5 text-center">
                <span className="text-[10px] text-neutral-400 uppercase font-medium">Proteína</span>
                <div className="text-base font-bold text-[#FF6B6B] font-mono mt-0.5">
                  {coachPlan.targetProtein}g
                </div>
                <span className="text-[10px] text-neutral-500">30% total</span>
              </div>
              <div className="bg-[#10121a] p-2.5 rounded-xl border border-white/5 text-center">
                <span className="text-[10px] text-neutral-400 uppercase font-medium">Carbs</span>
                <div className="text-base font-bold text-[#FF8E53] font-mono mt-0.5">
                  {coachPlan.targetCarbs}g
                </div>
                <span className="text-[10px] text-neutral-500">43% total</span>
              </div>
              <div className="bg-[#10121a] p-2.5 rounded-xl border border-white/5 text-center">
                <span className="text-[10px] text-neutral-400 uppercase font-medium">Grasas</span>
                <div className="text-base font-bold text-[#00E5FF] font-mono mt-0.5">
                  {coachPlan.targetFat}g
                </div>
                <span className="text-[10px] text-neutral-500">27% total</span>
              </div>
            </div>
          </div>

          {/* Guidelines Strip */}
          <div className="grid grid-cols-2 gap-3">
            <div className="p-3.5 rounded-2xl bg-[#1c1d27] border border-white/5">
              <div className="flex items-center gap-2 text-[#00E5FF]">
                <svg className="w-4 h-4 fill-none stroke-current" viewBox="0 0 24 24">
                  <path d="M13 10V3L4 14h7v7l9-11h-7z" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" />
                </svg>
                <span className="text-xs font-bold">Cardio & Pasos</span>
              </div>
              <p className="text-xs text-white font-medium mt-1">8,000 pasos / día</p>
              <p className="text-[11px] text-neutral-400 mt-0.5">Paseo suave o inclinación baja</p>
            </div>

            <div className="p-3.5 rounded-2xl bg-[#1c1d27] border border-white/5">
              <div className="flex items-center gap-2 text-[#bdf4ff]">
                <svg className="w-4 h-4 fill-none stroke-current" viewBox="0 0 24 24">
                  <path d="M12 2v20m-7-7a7 7 0 1014 0" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" />
                </svg>
                <span className="text-xs font-bold">Check-in Semanal</span>
              </div>
              <p className="text-xs text-white font-medium mt-1">{coachPlan.weeklyCheckinDay}</p>
              <p className="text-[11px] text-neutral-400 mt-0.5">Fotos de progreso + peso promedio</p>
            </div>
          </div>

          {/* Quick Contact Form */}
          <div className="p-4 rounded-2xl bg-[#1c1d27] border border-white/5">
            <h4 className="text-xs font-bold text-neutral-200 uppercase tracking-wider mb-2">
              Mensaje Rápido a tu Entrenador
            </h4>
            <form onSubmit={handleSend} className="space-y-2">
              <textarea
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                placeholder="Escribe tu consulta o duda sobre el plan asignado..."
                rows={2}
                className="w-full bg-[#10121a] border border-white/10 rounded-xl p-3 text-xs text-white placeholder-neutral-500 focus:outline-none focus:border-[#B388FF]"
              />
              <div className="flex items-center justify-between">
                {messageSent ? (
                  <span className="text-xs text-[#00E5FF] font-medium">
                    ✓ Mensaje enviado a Juan Pérez
                  </span>
                ) : (
                  <span className="text-[11px] text-neutral-500">Tiempo de respuesta usual: &lt; 2h</span>
                )}
                <button
                  type="submit"
                  disabled={!chatInput.trim()}
                  className="py-1.5 px-4 rounded-full bg-[#B388FF] text-black font-semibold text-xs disabled:opacity-40 hover:bg-[#c4a1ff] transition cursor-pointer"
                >
                  Enviar
                </button>
              </div>
            </form>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 bg-[#161820] border-t border-white/10 flex justify-end">
          <button
            onClick={onClose}
            className="py-2.5 px-6 rounded-full bg-white/10 hover:bg-white/20 text-white text-xs font-semibold transition cursor-pointer"
          >
            Entendido
          </button>
        </div>
      </div>
    </div>
  );
};
