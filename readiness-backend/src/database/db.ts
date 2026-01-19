import { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';
import * as fs from 'fs';
import * as path from 'path';

// PostgreSQL connection pool
let pool: Pool | null = null;

/**
 * Initialize database connection pool
 */
export function initDatabase(): Pool {
    if (pool) return pool;

    const databaseUrl = process.env.DATABASE_URL;

    if (!databaseUrl) {
        throw new Error('DATABASE_URL environment variable is required');
    }

    pool = new Pool({
        connectionString: databaseUrl,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : undefined,
        max: 20,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 2000,
    });

    pool.on('error', (err: Error) => {
        console.error('Unexpected database error:', err);
    });

    console.log('✅ PostgreSQL connection pool initialized');

    return pool;
}

/**
 * Get database pool instance
 */
export function getPool(): Pool {
    if (!pool) {
        return initDatabase();
    }
    return pool;
}

/**
 * Run database migrations
 */
export async function runMigrations(): Promise<void> {
    const pool = getPool();
    const schemaPath = path.join(__dirname, 'schema.sql');

    try {
        const schema = fs.readFileSync(schemaPath, 'utf8');
        await pool.query(schema);
        console.log('✅ Database migrations completed successfully');
    } catch (error) {
        console.error('❌ Migration failed:', error);
        throw error;
    }
}

/**
 * Execute a query
 */
export async function query<T extends QueryResultRow = any>(text: string, params?: any[]): Promise<QueryResult<T>> {
    const pool = getPool();
    return pool.query<T>(text, params);
}

/**
 * Get a client from the pool for transactions
 */
export async function getClient(): Promise<PoolClient> {
    const pool = getPool();
    return pool.connect();
}

/**
 * Close database connections (for graceful shutdown)
 */
export async function closeDatabase(): Promise<void> {
    if (pool) {
        await pool.end();
        pool = null;
        console.log('✅ Database connections closed');
    }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
    console.log('SIGTERM received, closing database...');
    await closeDatabase();
    process.exit(0);
});

process.on('SIGINT', async () => {
    console.log('SIGINT received, closing database...');
    await closeDatabase();
    process.exit(0);
});
