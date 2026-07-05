import { useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../lib/supabase'; // Assuming you have a Supabase client exported here
import { Recipe } from '../types'; // Assuming you have your types defined

interface UpvoteVariables {
  recipeId: string;
  userId: string;
}

/**
 * A custom hook demonstrating best practices for Optimistic UI updates
 * using TanStack Query (React Query) and Supabase.
 */
export function useUpvoteRecipe() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ recipeId, userId }: UpvoteVariables) => {
      // 1. Perform the actual Supabase mutation
      const { data, error } = await supabase
        .from('recipe_votes')
        .insert([{ recipe_id: recipeId, user_id: userId }])
        .select()
        .single();

      if (error) throw new Error(error.message);
      return data;
    },
    
    // 2. onMutate fires immediately before the mutation function runs.
    // This is where we perform the optimistic UI update.
    onMutate: async (newVote) => {
      // Cancel any outgoing refetches for this recipe to prevent them from
      // overwriting our optimistic update before the server responds.
      await queryClient.cancelQueries({ queryKey: ['recipes', newVote.recipeId] });

      // Snapshot the previous value so we can roll back if the mutation fails.
      const previousRecipe = queryClient.getQueryData<Recipe>(['recipes', newVote.recipeId]);

      // Optimistically update the cache with the new projected value.
      // E.g., we increment the upvote count instantly.
      if (previousRecipe) {
        queryClient.setQueryData<Recipe>(['recipes', newVote.recipeId], {
          ...previousRecipe,
          upvotes: previousRecipe.upvotes + 1,
          has_voted: true,
        });
      }

      // Return a context object with the snapshotted value.
      return { previousRecipe, newVote };
    },
    
    // 3. If the mutation fails, use the context returned from onMutate to roll back.
    onError: (err, newVote, context) => {
      console.error("Upvote failed, rolling back UI...", err);
      if (context?.previousRecipe) {
        queryClient.setQueryData(['recipes', context.newVote.recipeId], context.previousRecipe);
      }
    },
    
    // 4. Always refetch after error or success to ensure the client is perfectly
    // synchronized with the server's authoritative state.
    onSettled: (data, error, variables) => {
      queryClient.invalidateQueries({ queryKey: ['recipes', variables.recipeId] });
    },
  });
}
