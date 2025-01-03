CREATE OR REPLACE FUNCTION "Gnutella".recursive_dfs(
    current_node INT,
    target INT,
    max_depth INT,
    current_depth INT,
    current_path INT[]
) RETURNS VOID AS $$
DECLARE
    neighbors RECORD;
BEGIN
    -- Check if the current node is the target node
    IF current_node = target THEN
        INSERT INTO temp_path_cost (path, cost) VALUES (current_path, current_depth - 1);
        RETURN;
    END IF;

    -- If the depth limit is reached, skip this path
    IF current_depth >= max_depth THEN
        RETURN;
    END IF;

    -- Find and recursively call neighbors not in the current path
    FOR neighbors IN
        SELECT destination_node_id
        FROM "Gnutella"."p2p-Gnutella08"
        WHERE source_node_id = current_node
        AND NOT (destination_node_id = ANY(current_path))
    LOOP
        PERFORM "Gnutella".recursive_dfs(neighbors.destination_node_id, target, max_depth, current_depth + 1, current_path || neighbors.destination_node_id);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "Gnutella".find_shortest_DFS_recursive(
    source INT,
    target INT,
    max_depth INT DEFAULT 10
)
RETURNS TABLE(path INT[], cost INT) AS $$
DECLARE
    shortest_path INT[];
    shortest_cost INT := max_depth + 1;
BEGIN
    -- Create a temporary table
    EXECUTE 'CREATE TEMPORARY TABLE IF NOT EXISTS temp_path_cost (path INT[], cost INT) ON COMMIT DROP';

    -- Start the recursive DFS with the initial node
    -- Add 1 to max_depth when calling the recursive_dfs function
    PERFORM "Gnutella".recursive_dfs(source, target, max_depth + 1, 1, ARRAY[source]);

    -- Retrieve the shortest path from the temp table
    SELECT tpc.path, tpc.cost
    INTO shortest_path, shortest_cost
    FROM temp_path_cost tpc
    ORDER BY tpc.cost
    LIMIT 1;

    -- Return the shortest path found, if any
    IF shortest_path IS NOT NULL THEN
        RETURN QUERY SELECT shortest_path, shortest_cost;
    END IF;

    RETURN;
END;
$$ LANGUAGE plpgsql;
