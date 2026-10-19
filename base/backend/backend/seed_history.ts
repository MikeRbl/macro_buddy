import mongoose from 'mongoose';
import dotenv from 'dotenv';
// Ajusta estas rutas si tus modelos están en una carpeta diferente
import User from './models/User'; 
import UserWorkout from './models/UserWorkout';
import Workout from './models/Workout';

dotenv.config();

async function seedHistory() {
  try {
    console.log('Conectando a MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI as string);

    // 1. Buscar a BigMike
    const bigMike = await User.findOne({ username: 'BigMike' });
    if (!bigMike) throw new Error('Usuario BigMike no encontrado');

    // 2. Buscar alguna rutina de la biblioteca para usarla de base
    const routine = await Workout.findOne();
    if (!routine) throw new Error('No hay rutinas en la biblioteca. Crea una primero.');

    console.log(`Generando 30 días de historial para ${bigMike.username}...`);

    // 3. Generar un entrenamiento diario por los últimos 30 días
    const hoy = new Date();
    const workoutsToInsert = [];

    for (let i = 1; i <= 30; i++) {
      const fechaHistorica = new Date(hoy);
      fechaHistorica.setDate(hoy.getDate() - i);

      workoutsToInsert.push({
        user: bigMike._id,
        workout: routine._id,
        name: `${routine.name} (Automático)`,
        duration: Math.floor(Math.random() * (5400 - 2700 + 1) + 2700), // Entre 45 y 90 mins
        volume: Math.floor(Math.random() * (12000 - 5000 + 1) + 5000), // Volumen aleatorio
        createdAt: fechaHistorica,
        exercises: [] // Puedes rellenar esto si tu esquema lo hace obligatorio
      });
    }

    await UserWorkout.insertMany(workoutsToInsert);
    console.log('¡Éxito! 30 entrenamientos inyectados. Revisa tu Dashboard.');
    
    process.exit(0);
  } catch (error) {
    console.error('Error inyectando datos:', error);
    process.exit(1);
  }
}

seedHistory();
