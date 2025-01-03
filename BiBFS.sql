-- Function to reverse elements of an array and remove the first one
CREATE OR REPLACE FUNCTION "Gnutella".reverse_array_remove_first(arr INT[])
RETURNS INT[] LANGUAGE plpgsql AS $$
DECLARE
    result INT[];
BEGIN
    SELECT array_agg(val)
    FROM (
        SELECT unnest(arr) AS val
        ORDER BY array_length(arr, 1) - generate_subscripts(arr, 1)
    ) AS reversed_array
    INTO result;
    result := result[2:array_length(result, 1)]; -- Remove the first element
    RETURN result;
END;
$$;

-- Recursive helper for bidirectional BFS
CREATE OR REPLACE FUNCTION "Gnutella".bidirectional_BFS_recursive_helper(
    source INT, target INT, forward_frontier INT[][], backward_frontier INT[][],
    forward_visited INT[], backward_visited INT[], max_depth INT, current_depth INT
)
RETURNS TABLE(path INT[], cost INT) LANGUAGE plpgsql AS $$
DECLARE
    next_forward_frontier INT[][];
    next_backward_frontier INT[][];
    forward_path INT[];
    backward_path INT[];
    forward_node INT;
    backward_node INT;
    new_forward_path INT[];
    new_backward_path INT[];
BEGIN
    RAISE NOTICE 'Current Depth: %, Forward Frontier: %, Backward Frontier: %', current_depth, forward_frontier, backward_frontier;

    IF current_depth > max_depth THEN
        RAISE NOTICE 'Maximum depth reached, terminating search';
        RETURN;
    END IF;

    IF array_length(forward_frontier, 1) IS NULL OR array_length(backward_frontier, 1) IS NULL THEN
        RAISE NOTICE 'One of the frontiers is empty, terminating search';
        RETURN;
    END IF;

    next_forward_frontier := '{}';
    next_backward_frontier := '{}';

    -- Check for intersection of forward and backward frontiers
    FOREACH forward_path SLICE 1 IN ARRAY forward_frontier LOOP
        forward_node := forward_path[array_length(forward_path, 1)];

        FOREACH backward_path SLICE 1 IN ARRAY backward_frontier LOOP
            backward_node := backward_path[array_length(backward_path, 1)];
            IF forward_node = backward_node THEN
                RAISE NOTICE 'Intersection found at node: %', forward_node;
                RETURN QUERY SELECT forward_path || "Gnutella".reverse_array_remove_first(backward_path) AS path, 
                    array_length(forward_path || "Gnutella".reverse_array_remove_first(backward_path), 1) - 1 AS cost;
                RETURN;
            END IF;
        END LOOP;
    END LOOP;

    -- Extend forward search frontier
    FOREACH forward_path SLICE 1 IN ARRAY forward_frontier LOOP
        forward_node := forward_path[array_length(forward_path, 1)];

        FOR new_forward_path IN
            SELECT forward_path || destination_node_id
            FROM "Gnutella"."p2p-Gnutella08"
            WHERE source_node_id = forward_node
            AND NOT (forward_visited @> ARRAY[destination_node_id])
        LOOP
            next_forward_frontier := next_forward_frontier || ARRAY[new_forward_path];
            forward_visited := array_append(forward_visited, new_forward_path[array_length(new_forward_path, 1)]);
        END LOOP;
    END LOOP;

    -- Extend backward search frontier
    FOREACH backward_path SLICE 1 IN ARRAY backward_frontier LOOP
        backward_node := backward_path[array_length(backward_path, 1)];

        FOR new_backward_path IN
            SELECT backward_path || source_node_id
            FROM "Gnutella"."p2p-Gnutella08"
            WHERE destination_node_id = backward_node
            AND NOT (backward_visited @> ARRAY[source_node_id])
        LOOP
            next_backward_frontier := next_backward_frontier || ARRAY[new_backward_path];
            backward_visited := array_append(backward_visited, new_backward_path[array_length(new_backward_path, 1)]);
        END LOOP;
    END LOOP;

    -- Recur with next depth frontiers
    RETURN QUERY SELECT * FROM "Gnutella".bidirectional_BFS_recursive_helper(
        source, target, next_forward_frontier, next_backward_frontier,
        forward_visited, backward_visited, max_depth, current_depth + 1
    );
END;
$$;

-- Function to initiate bidirectional BFS
CREATE OR REPLACE FUNCTION "Gnutella".find_shortest_bidirectional_BFS(source INT, target INT, max_depth INT DEFAULT 10)
RETURNS TABLE(path INT[], cost INT) LANGUAGE plpgsql AS $$
DECLARE
    direct_connection_exists BOOLEAN;
BEGIN
    IF source = target THEN
        RETURN QUERY SELECT ARRAY[source] AS path, 0 AS cost;
        RETURN;
    END IF;

    -- Immediate check for direct connection to handle the 1-level case
    SELECT EXISTS (
        SELECT 1
        FROM "Gnutella"."p2p-Gnutella08"
        WHERE (source_node_id = source AND destination_node_id = target)
           OR (source_node_id = target AND destination_node_id = source)
    ) INTO direct_connection_exists;

    IF direct_connection_exists THEN
        RETURN QUERY SELECT ARRAY[source, target] AS path, 1 AS cost;
        RETURN;
    END IF;

    RETURN QUERY SELECT * FROM "Gnutella".bidirectional_BFS_recursive_helper(
        source, target, ARRAY[ARRAY[source]], ARRAY[ARRAY[target]], ARRAY[source], ARRAY[target], max_depth, 1
    );
END;
$$;