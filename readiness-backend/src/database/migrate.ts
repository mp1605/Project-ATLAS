import dotenv from 'dotenv';
import { runMigrations, closeDatabase } from './db';

// Load environment variables
dotenv.config();

/**
 * Run database migrations
 * Usage: npm run migrate
 */
async function migrate() {
    console.log('🔄 Running database migrations...');

    try {
        await runMigrations();
        console.log('✅ All migrations completed successfully');
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration failed:', error);
        process.exit(1);
    } finally {
        await closeDatabase();
    }
}

migrate();
