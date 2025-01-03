import psycopg2
import random
import time
import networkx as nx



hostname = 'localhost'
database = 'GraphSQL'
username = '0000000'
password = '00000000'
port = '9090'

# Connect to the PostgreSQL database
conn = psycopg2.connect(
    host=hostname,
    dbname=database,
    user=username,
    password=password,
    port=port
)

#conn = psycopg2.connect(dbname=dbname, user=user, password=password, host=host, port=port)
cur = conn.cursor()

# Schema and table name
schema_name = "Road networks"
table_name = "roadNet-TX"
max_depth=1
# Predefined array of node pairs [(start_node_id, destination_node_id)]
node_pairs = [
(801127, 801128),
    (801127, 814478),
    (801127, 822596),
    (801128, 823718),
    (801129, 803814),
    (801130,825034),
    (801131,812759),
    (801132,812825),
    (801133,800514),
    (801135,802940),


    # Add more node pairs as needed
]

# Load graph from the database
def load_graph():
    cur.execute(f'SELECT source_node_id, destination_node_id FROM "{schema_name}"."{table_name}"')
    edges = cur.fetchall()
    G = nx.Graph()
    G.add_edges_from(edges)
    return G

# Function to measure execution time for SQL queries with EXPLAIN ANALYZE
def measure_time(query):
    cur.execute("EXPLAIN ANALYZE " + query)
    analysis = cur.fetchall()
    exec_time = float(analysis[-1][0].split(':')[1].split('ms')[0].strip())
    return exec_time

# Function to measure execution time for procedural calls
def measure_procedure_time(query):
    start_time = time.time()
    cur.execute(query)
    conn.commit()  # Ensure changes are committed if the block makes any.
    return time.time() - start_time

# Function to calculate the shortest path using NetworkX
def calculate_shortest_path_networkx(G, start_node, end_node):
    try:
        path = nx.shortest_path(G, source=start_node, target=end_node)
        return len(path) - 1  # returns the number of edges in the path
    except nx.NetworkXNoPath:
        return None  # or any indication that no path exists

# Queries for each method, modified to format with random nodes
queries = {
    "udf-bfs": 'SELECT * FROM "{0}".find_shortest_BFS_recursive({1}, {2},{4})',
    "udf-bfs-adj":'SELECT * FROM "{0}".find_shortest_BFS_adj({1}, {2},{4})',
    "udf-dfs-adj":'SELECT * FROM "{0}".find_shortest_path({1}, {2},{4})',
    "udf-bidirectional-bfs": 'SELECT * FROM "{0}".find_shortest_bidirectional_BFS({1}, {2},{4})',
    "udf-bidirectional-bfs": 'SELECT * FROM "{0}".find_shortest_bidirectional_BFS_adj({1}, {2},{4})',
    "udf-dfs":'SELECT * FROM "{0}".find_shortest_DFS_recursive({1}, {2},{4})',
    "cte-bfs": '''
DO $$
DECLARE
    start_node INTEGER := {1};
    end_node INTEGER := {2};
    result_path INTEGER[];
    result_path_length INTEGER;
    max_depth INTEGER := {4};
BEGIN
    WITH RECURSIVE bfs AS (
        -- Initial selection from the start node
        SELECT
            g.source_node_id,
            g.destination_node_id,
            ARRAY[g.source_node_id, g.destination_node_id] AS path, -- Include destination in the path immediately
            1 AS path_length
        FROM
            "Road networks"."roadNet-TX" g
        WHERE
            g.source_node_id = start_node

        UNION ALL

        -- Recursive expansion
        SELECT
            g.source_node_id,
            g.destination_node_id,
            b.path || g.destination_node_id, -- Extend the path
            b.path_length + 1
        FROM
            "Road networks"."roadNet-TX" g
        JOIN
            bfs b ON g.source_node_id = b.destination_node_id
        WHERE
            NOT g.destination_node_id = ANY(b.path) -- Avoid cycles
            AND b.path_length < max_depth -- Limit depth to prevent excessive recursion
    )
    -- Select the shortest path from all collected paths that reach the end node
    SELECT
        path,
        path_length
    INTO result_path, result_path_length
    FROM
        bfs
    WHERE
        destination_node_id = end_node
    ORDER BY
        path_length ASC
    LIMIT 1;

    -- Output the result
    RAISE NOTICE 'Shortest path: %', result_path;
    RAISE NOTICE 'Path length: %', result_path_length;
END $$;


    ''',
        "cte-bfs-with-adjacency": '''
DO $$
DECLARE
    start_node INTEGER := {1};
    end_node INTEGER := {2};
    result_path INTEGER[];
    result_path_length INTEGER;
    max_depth INTEGER := {4};
BEGIN
    WITH RECURSIVE
    expanded AS (
        SELECT
            source_node_id,
            unnest(adjacency_nodes) AS destination_node_id
        FROM
            "Road networks"."roadNet_TX_Adjacency"
    ),
    bfs AS (
        SELECT
            source_node_id,
            destination_node_id,
            ARRAY[source_node_id, destination_node_id] AS path,
            1 AS path_length,
            destination_node_id = end_node AS reached_dest
        FROM
            expanded
        WHERE
            source_node_id = start_node
        UNION ALL
        SELECT
            e.source_node_id,
            e.destination_node_id,
            b.path || e.destination_node_id,
            b.path_length + 1,
            e.destination_node_id = end_node AS reached_dest
        FROM
            expanded e
        JOIN
            bfs b ON e.source_node_id = b.destination_node_id
        WHERE
            NOT e.destination_node_id = ANY(b.path)
            AND b.path_length < max_depth
            AND NOT b.reached_dest
    ),
    valid_paths AS (
        SELECT
            path,
            path_length
        FROM
            bfs
        WHERE
            reached_dest
    )
    SELECT
        path,
        path_length
    INTO result_path, result_path_length
    FROM
        valid_paths
    ORDER BY
        path_length ASC,
        path -- This additional sorting helps select a consistent path when paths have equal lengths
    LIMIT 1;

    -- Output the result
    RAISE NOTICE 'Shortest path: %', result_path;
    RAISE NOTICE 'Path length: %', result_path_length;
END $$;

    ''',
    "cte-bidirectional-bfs": '''
DO $$
DECLARE
    start_node INTEGER := {1};
    end_node INTEGER := {2};
    max_depth INTEGER := {4};
    result_path INTEGER[];
    actual_path_length INTEGER;
BEGIN
    -- Forward and backward searches
    WITH RECURSIVE
    forward_bfs AS (
        SELECT g.source_node_id,
               g.destination_node_id,
               ARRAY[g.source_node_id, g.destination_node_id] AS path,
               1 AS depth  -- Starting depth
        FROM "Road networks"."roadNet-TX" g
        WHERE g.source_node_id = start_node
        UNION ALL
        SELECT g.source_node_id,
               g.destination_node_id,
               f.path || g.destination_node_id,
               f.depth + 1
        FROM "Road networks"."roadNet-TX" g
        JOIN forward_bfs f ON g.source_node_id = f.destination_node_id
        WHERE NOT g.destination_node_id = ANY(f.path)
          AND f.depth < max_depth
    ),
    backward_bfs AS (
        SELECT g.destination_node_id AS source_node_id,
               g.source_node_id AS destination_node_id,
               ARRAY[g.destination_node_id, g.source_node_id] AS path,
               1 AS depth
        FROM "Road networks"."roadNet-TX" g
        WHERE g.destination_node_id = end_node
        UNION ALL
        SELECT g.destination_node_id,
               g.source_node_id,
               b.path || g.source_node_id,
               b.depth + 1
        FROM "Road networks"."roadNet-TX" g
        JOIN backward_bfs b ON g.destination_node_id = b.source_node_id
        WHERE NOT g.source_node_id = ANY(b.path)
          AND b.depth < max_depth
    ),
    intersection AS (
        SELECT f.path || array_agg(elem ORDER BY rn DESC) AS complete_path
        FROM forward_bfs f
        JOIN backward_bfs b ON f.destination_node_id = b.source_node_id,
        LATERAL (
            SELECT elem, row_number() OVER () AS rn
            FROM unnest(b.path) AS t(elem)
        ) sub
        WHERE f.depth + b.depth <= max_depth + 1 AND elem != f.destination_node_id
        GROUP BY f.path, f.destination_node_id  -- Include necessary columns
        ORDER BY array_length(f.path, 1) + min(array_length(b.path, 1)) - 1 ASC  -- Use MIN to aggregate array_length(b.path, 1)
        LIMIT 1
    )
    SELECT complete_path INTO result_path
    FROM intersection;

    -- Ensure the path ends at the end_node
    IF result_path[array_upper(result_path, 1)] != end_node THEN
        result_path := result_path[1:array_position(result_path, end_node)];
    END IF;

    -- Calculate actual path length as number of edges
    actual_path_length := array_length(result_path, 1) - 1;
    
    -- Output the result
    RAISE NOTICE 'Shortest path: %', result_path;
    RAISE NOTICE 'Path length: %', actual_path_length;
END $$;

    ''',


"cte-bidirectional-bfs-with-adjacency": '''
DO $$
DECLARE
    start_node INTEGER := {1};
    end_node INTEGER := {2};
    max_depth INTEGER := {4};
    result_path INTEGER[];
    result_path_length INTEGER;
BEGIN
    WITH RECURSIVE
    expanded AS (
        SELECT
            source_node_id,
            unnest(adjacency_nodes) AS destination_node_id
        FROM
            "Road networks"."roadNet_TX_Adjacency"
    ),
    forward_bfs AS (
        SELECT
            source_node_id,
            destination_node_id,
            ARRAY[source_node_id, destination_node_id] AS path,
            1 AS depth
        FROM
            expanded
        WHERE
            source_node_id = start_node
        UNION ALL
        SELECT
            e.source_node_id,
            e.destination_node_id,
            f.path || e.destination_node_id,
            f.depth + 1
        FROM
            expanded e
        JOIN
            forward_bfs f ON e.source_node_id = f.destination_node_id
        WHERE
            NOT e.destination_node_id = ANY(f.path)
            AND f.depth < max_depth
    ),
    backward_bfs AS (
        SELECT
            destination_node_id AS source_node_id,
            source_node_id AS destination_node_id,
            ARRAY[destination_node_id, source_node_id] AS path,
            1 AS depth
        FROM
            expanded
        WHERE
            destination_node_id = end_node
        UNION ALL
        SELECT
            e.destination_node_id AS source_node_id,
            e.source_node_id AS destination_node_id,
            b.path || e.source_node_id,
            b.depth + 1
        FROM
            expanded e
        JOIN
            backward_bfs b ON e.destination_node_id = b.source_node_id
        WHERE
            NOT e.source_node_id = ANY(b.path)
            AND b.depth < max_depth
    ),
    intersection AS (
        SELECT
            f.path || array_remove(array_agg(b_elem ORDER BY b_idx DESC), f.destination_node_id) AS full_path,
            array_length(f.path, 1) + array_length(array_remove(b.path, f.destination_node_id), 1) - 1 AS total_length
        FROM
            forward_bfs f
        JOIN
            backward_bfs b ON f.destination_node_id = b.source_node_id
        CROSS JOIN LATERAL unnest(b.path) WITH ORDINALITY AS b_arr(b_elem, b_idx)
        WHERE
            b_idx > 1
        GROUP BY f.path, b.path, f.destination_node_id
        ORDER BY
            total_length
        LIMIT 1
    )
    SELECT
        full_path,
        array_length(full_path, 1) - 1 INTO result_path, result_path_length
    FROM
        intersection;

    -- Output the result
    RAISE NOTICE 'Shortest path: %', result_path;
    RAISE NOTICE 'Path length: %', result_path_length;
END $$;


    ''',


    "cte-dfs": '''
DO $$
DECLARE
    start_node INTEGER := {1};
    end_node INTEGER := {2};
    max_depth INTEGER :={4};  -- Maximum depth you want to allow in the search
    result_path INTEGER[];
    actual_path_length INTEGER;
BEGIN
    -- Depth-first search with depth control
    WITH RECURSIVE dfs AS (
        SELECT
            g.source_node_id,
            g.destination_node_id,
            ARRAY[g.source_node_id, g.destination_node_id] AS path,  -- Include destination to start the path correctly
            ARRAY[g.source_node_id, g.destination_node_id] AS visited,
            1 AS depth  -- Starting depth
        FROM
            "Road networks"."roadNet-TX" g
        WHERE
            g.source_node_id = start_node
        UNION ALL
        SELECT
            g.source_node_id,
            g.destination_node_id,
            d.path || g.destination_node_id,
            d.visited || g.destination_node_id,
            d.depth + 1  -- Incrementing depth
        FROM
            "Road networks"."roadNet-TX" g
        JOIN
            dfs d ON g.source_node_id = d.destination_node_id
        WHERE
            NOT g.destination_node_id = ANY(d.visited)
            AND d.depth < max_depth  -- Depth limit
    )
    SELECT
        path INTO result_path
    FROM
        dfs
    WHERE
        destination_node_id = end_node
    ORDER BY
        array_length(path, 1) ASC
    LIMIT 1;

    -- Calculate actual path length as number of edges
    actual_path_length := array_length(result_path, 1) - 1;

    -- Output the result
    RAISE NOTICE 'DFS path: %', result_path;
    RAISE NOTICE 'Path length: %', actual_path_length;
END $$;

    ''',


       "cte-dfs-with-adjacency": '''
DO $$
DECLARE
    start_node INTEGER := {1};
    end_node INTEGER := {2};
    max_depth INTEGER :={4};  -- Maximum depth you want to allow in the search
    result_path INTEGER[];
    actual_path_length INTEGER;
BEGIN
    -- Depth-first search with depth control using the adjacency array
    WITH RECURSIVE expanded AS (
        SELECT
            source_node_id,
            unnest(adjacency_nodes) AS destination_node_id
        FROM
            "Road networks"."roadNet_TX_Adjacency"
    ),
    dfs AS (
        SELECT
            e.source_node_id,
            e.destination_node_id,
            ARRAY[e.source_node_id, e.destination_node_id] AS path, -- Include the first destination to start the path correctly
            ARRAY[e.source_node_id, e.destination_node_id] AS visited,
            1 AS depth  -- Starting depth
        FROM
            expanded e
        WHERE
            e.source_node_id = start_node
        UNION ALL
        SELECT
            e.source_node_id,
            e.destination_node_id,
            d.path || e.destination_node_id,
            d.visited || e.destination_node_id,
            d.depth + 1  -- Incrementing depth
        FROM
            expanded e
        JOIN
            dfs d ON e.source_node_id = d.destination_node_id
        WHERE
            NOT e.destination_node_id = ANY(d.visited)
            AND d.depth < max_depth  -- Depth limit
    )
    SELECT
        path INTO result_path
    FROM
        dfs
    WHERE
        destination_node_id = end_node
    ORDER BY
        array_length(path, 1) ASC
    LIMIT 1;

    -- Calculate actual path length as number of edges
    actual_path_length := array_length(result_path, 1) - 1;

    -- Output the result
    RAISE NOTICE 'DFS path: %', result_path;
    RAISE NOTICE 'Path length: %', actual_path_length;
END $$;

    '''
}


# Load the graph
G = load_graph()

# Main execution loop using the predefined node pairs array
results = {method: [] for method in queries}
results['networkx'] = []  # Add a list for NetworkX results

for start_node, end_node in node_pairs:
    print(f"Processing node pair: {start_node}, {end_node}")

    # Measure execution time for NetworkX calculation
    start_time = time.time()
    path_length = calculate_shortest_path_networkx(G, start_node, end_node)
    exec_time = time.time() - start_time
    results['networkx'].append(exec_time)

    for method, query_template in queries.items():
        # Format the query with the start_node, end_node, and other required parameters
        query = query_template.format(schema_name, start_node, end_node, table_name,max_depth)
        exec_time = measure_procedure_time(query)
        results[method].append(exec_time)

# Calculate mean execution times
mean_results = {method: sum(times) / len(times) for method, times in results.items()}
print(mean_results)

# Close the connection
cur.close()
conn.close()