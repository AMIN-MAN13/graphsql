-- Recursive helper function for BFS
CREATE OR REPLACE FUNCTION "Rostock-Road".find_shortest_BFS_recursive_helper(
    source INT, target INT, frontier INT[][], visited INT[], max_depth INT, current_depth INT
)
RETURNS TABLE(path INT[], cost INT) AS $$
DECLARE
    next_frontier INT[][];
    current_path INT[];
    current_node INT;
    new_path INT[];
BEGIN
    IF current_depth > max_depth THEN
        RETURN; -- Maximum depth reached, stop search
    END IF;

    next_frontier := '{}'; -- Clear next frontier

    -- Loop through each path in the current frontier
    FOREACH current_path SLICE 1 IN ARRAY frontier LOOP
        -- Get the current node from the path
        current_node := current_path[array_length(current_path, 1)];

        -- Check if the current node is the target
        IF current_node = target THEN
            RETURN QUERY SELECT current_path, array_length(current_path, 1) - 1;
            RETURN; -- Path found, return immediately
        END IF;

        -- Find and add new paths extending from the current node (undirected)
        FOR new_path IN
            SELECT current_path || node
            FROM (
                SELECT destination_node_id AS node
                FROM "Rostock-Road"."roadNet-TX"
                WHERE source_node_id = current_node
                UNION
                SELECT source_node_id AS node
                FROM "Rostock-Road"."roadNet-TX"
                WHERE destination_node_id = current_node
            ) AS neighbors
            WHERE NOT (visited @> ARRAY[node])
        LOOP
            next_frontier := next_frontier || ARRAY[new_path];
            visited := array_append(visited, new_path[array_length(new_path, 1)]);
        END LOOP;
    END LOOP;

    -- Recur with next depth and the next frontier
    RETURN QUERY SELECT * FROM "Rostock-Road".find_shortest_BFS_recursive_helper(
        source, target, next_frontier, visited, max_depth, current_depth + 1
    );
END;
$$ LANGUAGE plpgsql;

-- Main BFS function to initiate the recursive search
CREATE OR REPLACE FUNCTION "Rostock-Road".find_shortest_BFS_recursive(
    source INT, 
    target INT, 
    max_depth INT DEFAULT 10
)
RETURNS TABLE(path INT[], cost INT) AS $$
BEGIN
    -- Call the recursive BFS helper function
    RETURN QUERY SELECT * FROM "Rostock-Road".find_shortest_BFS_recursive_helper(
        source, target, ARRAY[ARRAY[source]], ARRAY[source], max_depth + 1, 1
    );
END;
$$ LANGUAGE plpgsql;
