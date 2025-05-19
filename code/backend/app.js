// Load environment variables
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const mysql = require('mysql2/promise');
const Redis = require('ioredis');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { promisify } = require('util');

const app = express();
const PORT = process.env.PORT || 3000;
let server;

// Database initialization function
async function initializeDatabase() {
  let connection;
  
  try {
    console.log('Attempting to connect to MySQL server...');
    
    // First connect without specifying a database
    connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT || 3306
    });
    
    console.log('Connected to MySQL server successfully');
    
    // Check if database exists
    const [rows] = await connection.query(
      `SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = ?`,
      [process.env.DB_NAME]
    );
    
    // Create database if it doesn't exist
    if (rows.length === 0) {
      console.log(`Database '${process.env.DB_NAME}' not found, creating it...`);
      await connection.query(`CREATE DATABASE IF NOT EXISTS \`${process.env.DB_NAME}\``);
      console.log(`Database '${process.env.DB_NAME}' created successfully`);
    } else {
      console.log(`Database '${process.env.DB_NAME}' already exists`);
    }
    
    // Switch to the database
    await connection.query(`USE \`${process.env.DB_NAME}\``);
    
    // Create tables if they don't exist
    console.log('Creating tables if they don\'t exist...');
    await connection.query(`
      CREATE TABLE IF NOT EXISTS items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_created_at (created_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('Tables created successfully');
    
    // Close this connection as we'll use the pool for normal operations
    await connection.end();
    console.log('Database initialization completed successfully');
    
    return true;
  } catch (error) {
    console.error('Database initialization failed:', error);
    if (connection) {
      try {
        await connection.end();
      } catch (err) {
        console.error('Error closing connection:', err);
      }
    }
    return false;
  }
}

// Security middleware
app.use(helmet());  // Adds various HTTP headers for security

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);  // Apply rate limiting to API routes

// Standard middleware
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

// Database connection pool with explicit authentication settings
const dbPool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT || 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  // Add this for MySQL 8+ compatibility
  authPlugins: {
    mysql_native_password: () => () => Buffer.from(process.env.DB_PASSWORD + '\0')
  }
});

// Redis connection (cluster mode)
let redisClient;
try {
  const redisNodes = process.env.REDIS_NODES.split(',').map(node => {
    const [host, port] = node.split(':');
    return { host, port: parseInt(port) };
  });
  
  redisClient = new Redis.Cluster(redisNodes, {
    redisOptions: {
      password: process.env.REDIS_PASSWORD || '',
      connectTimeout: 10000,
      tls: process.env.REDIS_TLS === 'true' ? {} : undefined
    },
    // Customize cluster behavior
    clusterRetryStrategy: times => Math.min(times * 50, 2000),
    scaleReads: 'all' // Read from all replicas for load balancing
  });
  
  redisClient.on('error', (err) => {
    console.error('Redis cluster error:', err);
  });

  redisClient.on('connect', () => {
    console.log('Successfully connected to Redis cluster');
  });
} catch (error) {
  console.error('Redis cluster connection error:', error);
}

// Root route
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to the 4-tier application API',
    version: process.env.APP_VERSION || '1.0.0',
    endpoints: {
      health: '/api/health',
      items: '/api/items',
      itemById: '/api/items/:id'
    },
    documentation: '/api-docs' // For future Swagger/OpenAPI documentation
  });
});

// Enhanced health check endpoint with detailed diagnostics
app.get('/api/health', async (req, res) => {
  let dbStatus = false;
  let cacheStatus = false;
  let dbError = null;
  let cacheError = null;
  
  // Check database connection
  try {
    console.log('Attempting database connection...');
    const [result] = await dbPool.query('SELECT 1');
    if (result) {
      dbStatus = true;
      console.log('Database connection successful');
    }
  } catch (error) {
    dbError = {
      message: error.message,
      code: error.code,
      errno: error.errno,
      sqlState: error.sqlState,
      sqlMessage: error.sqlMessage
    };
    console.error('Database health check failed:', error);
  }
  
  // Check Redis connection
  try {
    console.log('Attempting Redis connection...');
    if (redisClient && redisClient.status === 'ready') {
      await redisClient.ping();
      cacheStatus = true;
      console.log('Redis connection successful');
    } else {
      console.log('Redis client not ready:', redisClient ? redisClient.status : 'null');
    }
  } catch (error) {
    cacheError = error.message;
    console.error('Redis health check failed:', error);
  }
  
  // Get memory usage
  const memoryUsage = process.memoryUsage();
  
  // Return health status with detailed diagnostics
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    database: {
      connected: dbStatus,
      error: dbError,
      config: {
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        database: process.env.DB_NAME,
        port: process.env.DB_PORT
      }
    },
    cache: {
      connected: cacheStatus,
      error: cacheError,
      config: {
        host: process.env.REDIS_HOST,
        port: process.env.REDIS_PORT
      }
    },
    environment: process.env.ENVIRONMENT || 'development',
    version: process.env.APP_VERSION || '1.0.0',
    node_version: process.version,
    memory: {
      rss: Math.round(memoryUsage.rss / 1024 / 1024) + 'MB',
      heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024) + 'MB',
      heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024) + 'MB'
    }
  });
});

// Get all items
app.get('/api/items', async (req, res) => {
  try {
    // Try to get from cache first
    if (redisClient && redisClient.status === 'ready') {
      const cachedItems = await redisClient.get('items');
      if (cachedItems) {
        console.log('Returning items from cache');
        return res.json(JSON.parse(cachedItems));
      }
    }
    
    // If not in cache, get from database
    const [rows] = await dbPool.query(
      'SELECT * FROM items ORDER BY created_at DESC LIMIT 100'  // Added limit for safety
    );
    
    // Store in cache for future requests
    if (redisClient && redisClient.status === 'ready') {
      await redisClient.set('items', JSON.stringify(rows), 'EX', 60); // Expire after 60 seconds
    }
    
    res.json(rows);
  } catch (error) {
    console.error('Error fetching items:', error);
    res.status(500).json({ 
      error: 'Failed to fetch items',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Get a single item by ID
app.get('/api/items/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Input validation
    if (!id || isNaN(parseInt(id))) {
      return res.status(400).json({ error: 'Invalid item ID' });
    }
    
    // Try to get from cache first
    if (redisClient && redisClient.status === 'ready') {
      const cachedItem = await redisClient.get(`item:${id}`);
      if (cachedItem) {
        console.log(`Returning item ${id} from cache`);
        return res.json(JSON.parse(cachedItem));
      }
    }
    
    // If not in cache, get from database using parameterized query for security
    const [rows] = await dbPool.query(
      'SELECT * FROM items WHERE id = ?',
      [id]
    );
    
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Item not found' });
    }
    
    // Store in cache for future requests
    if (redisClient && redisClient.status === 'ready') {
      await redisClient.set(`item:${id}`, JSON.stringify(rows[0]), 'EX', 300); // Expire after 5 minutes
    }
    
    res.json(rows[0]);
  } catch (error) {
    console.error(`Error fetching item ${req.params.id}:`, error);
    res.status(500).json({ 
      error: 'Failed to fetch item',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Create a new item
app.post('/api/items', async (req, res) => {
  try {
    const { name, description } = req.body;
    
    // Input validation
    if (!name || typeof name !== 'string' || name.length > 255) {
      return res.status(400).json({ error: 'Name is required and must be a string under 256 characters' });
    }
    
    if (!description || typeof description !== 'string') {
      return res.status(400).json({ error: 'Description is required and must be a string' });
    }
    
    const [result] = await dbPool.query(
      'INSERT INTO items (name, description) VALUES (?, ?)',
      [name, description]
    );
    
    // Invalidate cache
    if (redisClient && redisClient.status === 'ready') {
      await redisClient.del('items');
    }
    
    res.status(201).json({
      id: result.insertId,
      name,
      description,
      created_at: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error creating item:', error);
    res.status(500).json({ 
      error: 'Failed to create item',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Update an item
app.put('/api/items/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description } = req.body;
    
    // Input validation
    if (!id || isNaN(parseInt(id))) {
      return res.status(400).json({ error: 'Invalid item ID' });
    }
    
    if ((!name && !description) || 
        (name && (typeof name !== 'string' || name.length > 255)) || 
        (description && typeof description !== 'string')) {
      return res.status(400).json({ 
        error: 'At least one valid field (name or description) is required' 
      });
    }
    
    // Get the current item to merge with updates
    const [currentItem] = await dbPool.query(
      'SELECT * FROM items WHERE id = ?',
      [id]
    );
    
    if (currentItem.length === 0) {
      return res.status(404).json({ error: 'Item not found' });
    }
    
    // Update with new values or keep existing ones
    const updatedName = name || currentItem[0].name;
    const updatedDescription = description || currentItem[0].description;
    
    await dbPool.query(
      'UPDATE items SET name = ?, description = ?, updated_at = NOW() WHERE id = ?',
      [updatedName, updatedDescription, id]
    );
    
    // Invalidate cache
    if (redisClient && redisClient.status === 'ready') {
      await redisClient.del(`item:${id}`);
      await redisClient.del('items');
    }
    
    res.json({
      id: parseInt(id),
      name: updatedName,
      description: updatedDescription,
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    console.error(`Error updating item ${req.params.id}:`, error);
    res.status(500).json({ 
      error: 'Failed to update item',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Delete an item
app.delete('/api/items/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Input validation
    if (!id || isNaN(parseInt(id))) {
      return res.status(400).json({ error: 'Invalid item ID' });
    }
    
    const [result] = await dbPool.query(
      'DELETE FROM items WHERE id = ?',
      [id]
    );
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Item not found' });
    }
    
    // Invalidate cache
    if (redisClient && redisClient.status === 'ready') {
      await redisClient.del(`item:${id}`);
      await redisClient.del('items');
    }
    
    res.status(204).end();
  } catch (error) {
    console.error(`Error deleting item ${req.params.id}:`, error);
    res.status(500).json({ 
      error: 'Failed to delete item',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  
  // Log error details for debugging while keeping response secure
  console.error(`${err.name}: ${err.message}`);
  console.error(`Stack: ${err.stack}`);
  
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined,
    requestId: req.headers['x-request-id'] || 'unknown'  // Helps with tracking issues
  });
});

// Start server function with database initialization
async function startServer() {
  try {
    // Initialize database
    const dbInitialized = await initializeDatabase();
    if (!dbInitialized) {
      console.error('Failed to initialize database. Application may not function correctly.');
    }
    
    // Start the server
    server = app.listen(PORT, () => {
      console.log(`Backend server running on port ${PORT}`);
      console.log(`Environment: ${process.env.ENVIRONMENT || 'development'}`);
      console.log(`Node.js version: ${process.version}`);
      console.log(`Database host: ${process.env.DB_HOST}`);
      console.log(`Redis host: ${process.env.REDIS_HOST}`);
    });
    
    // Set timeouts
    server.timeout = 30000; // 30 seconds
    server.keepAliveTimeout = 65000; // 65 seconds (higher than ALB's 60 second timeout)
  } catch (error) {
    console.error('Failed to start application:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  
  // Stop accepting new connections
  if (server) {
    server.close(() => {
      console.log('HTTP server closed');
    });
  }
  
  // Close database connections
  try {
    await dbPool.end();
    console.log('Database connections closed');
  } catch (error) {
    console.error('Error closing database connections:', error);
  }
  
  // Close Redis connection
  if (redisClient) {
    try {
      await redisClient.quit();
      console.log('Redis connection closed');
    } catch (error) {
      console.error('Error closing Redis connection:', error);
    }
  }
  
  // Exit with success code
  process.exit(0);
});

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err);
  // Log to external monitoring service here if available
  
  // Exit with failure (will be restarted by PM2)
  process.exit(1);
});

// Call the function to start the server
startServer();