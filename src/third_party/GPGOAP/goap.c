/*
This block includes necessary headers and sets some compiler-specific options for Visual Studio.
It also includes custom headers for the Goal-Oriented Action Planning (GOAP) system and A* algorithm.
*/
#if defined( _MSC_VER )
#	define _CRT_SECURE_NO_WARNINGS  // Disable warnings about unsafe C functions like strcpy, sprintf, etc.
#	define snprintf _snprintf       // Use the Visual Studio-specific version of snprintf
#endif

#include "goap.h"   // GOAP header file for the planner
#include "astar.h"  // A* search algorithm header

#include <string.h> // String manipulation functions like strcmp, strlen
#include <stdio.h>  // Standard I/O functions like printf
#include <stdlib.h>  // Include for malloc, free, and strdup

/*
 * @brief Returns the index of the atom name or adds it if it's new.
 * This function checks if the atom name exists in the planner, and if not, adds it.
 * Returns the index of the atom name or -1 if the atom list is full.
 */
static int idx_for_atomname( actionplanner_t* ap, const char* atomname )
{
	int idx;
	for ( idx=0; idx < ap->numatoms; ++idx ) // Iterate over existing atom names
		if ( !strcmp( ap->atm_names[ idx ], atomname ) ) return idx; // If atom exists, return its index

	if ( idx < MAXATOMS )  // If there is room for more atoms
	{
		ap->atm_names[ idx ] = strdup(atomname);  // Copy the new atom name and store it
		ap->numatoms++;                           // Increase the number of atoms
		return idx;                               // Return the new index
	}

	return -1; // If atom list is full, return error (-1)
}

/*
 * @brief Returns the index of the action name or adds it if it's new.
 * Similar to the atom name function, this looks up the action name, adds it if new,
 * and returns its index, or -1 if the action list is full.
 */
static int idx_for_actionname( actionplanner_t* ap, const char* actionname )
{
	int idx;
	for ( idx=0; idx < ap->numactions; ++idx ) // Iterate over existing action names
		if ( !strcmp( ap->act_names[ idx ], actionname ) ) return idx; // If action exists, return its index

	if ( idx < MAXACTIONS )  // If there is room for more actions
	{
		ap->act_names[ idx ] = strdup(actionname);  // Copy the new action name and store it
		ap->act_costs[ idx ] = 1;                   // Set default action cost to 1
		ap->numactions++;                           // Increase the number of actions
		return idx;                                 // Return the new index
	}

	return -1; // If action list is full, return error (-1)
}


/*
 * @brief Clears the action planner by resetting atom and action counts and data.
 * This function resets the action planner's atoms, actions, and world states.
 */
void goap_actionplanner_clear( actionplanner_t* ap )
{
    // Free all atom names
    for (int i = 0; i < ap->numatoms; ++i) {
        if (ap->atm_names[i]) {
            free(ap->atm_names[i]);
            ap->atm_names[i] = NULL;
        }
    }
    ap->numatoms = 0;   // Reset the number of atoms

    // Free all action names and clear state
    for (int i = 0; i < ap->numactions; ++i) {
        if (ap->act_names[i]) {
            free(ap->act_names[i]);
            ap->act_names[i] = NULL;
        }
        ap->act_costs[i] = 0;      // Reset all action costs
        goap_worldstate_clear(ap->act_pre + i); // Clear preconditions for the action
        goap_worldstate_clear(ap->act_pst + i); // Clear postconditions for the action
    }
    ap->numactions = 0; // Reset the number of actions
}

/*
 * @brief Clears a world state by resetting its values and 'dontcare' flags.
 * A world state stores the current state of all atoms in the system.
 */
void goap_worldstate_clear( worldstate_t* ws )
{
	ws->values = 0LL;      // Reset all atom values (use a long long to store them as bits)
	ws->dontcare = -1LL;   // Set all 'dontcare' flags (this means we don't care about any atoms yet)
}

/*
 * @brief Sets a specific atom in the world state to a true/false value.
 * This function updates the world state with a new atom value and removes the 'dontcare' flag for that atom.
 */
bool goap_worldstate_set( actionplanner_t* ap, worldstate_t* ws, const char* atomname, bool value )
{
	const int idx = idx_for_atomname( ap, atomname ); // Find or add the atom's index
	if ( idx == -1 ) return false;                   // If atom index not found, return error

	// Set or clear the bit representing the atom's value in the world state
	ws->values = value ? ( ws->values | ( 1LL << idx ) ) : ( ws->values & ~( 1LL << idx ) );

	// Ensure we care about this atom by removing the 'dontcare' flag for it
	ws->dontcare &= ~( 1LL << idx );
	return true;
}

/*
 * @brief Sets the preconditions for an action in the planner.
 * This function specifies the precondition for a given action and atom.
 */
extern bool goap_set_pre( actionplanner_t* ap, const char* actionname, const char* atomname, bool value )
{
	const int actidx = idx_for_actionname( ap, actionname ); // Find or add the action index
	const int atmidx = idx_for_atomname( ap, atomname );     // Find or add the atom index
	if ( actidx == -1 || atmidx == -1 ) return false;        // If indices are invalid, return error
	goap_worldstate_set( ap, ap->act_pre+actidx, atomname, value ); // Set the precondition in the world state
	return true;
}

/*
 * @brief Sets the postconditions for an action in the planner.
 * Similar to the preconditions function, this sets postconditions for an action and atom.
 */
bool goap_set_pst( actionplanner_t* ap, const char* actionname, const char* atomname, bool value )
{
	const int actidx = idx_for_actionname( ap, actionname ); // Find or add the action index
	const int atmidx = idx_for_atomname( ap, atomname );     // Find or add the atom index
	if ( actidx == -1 || atmidx == -1 ) return false;        // If indices are invalid, return error
	goap_worldstate_set( ap, ap->act_pst+actidx, atomname, value ); // Set the postcondition in the world state
	return true;
}

/*
 * @brief Sets the cost for an action.
 * Updates the action cost for the planner, which affects the decision-making process.
 */
bool goap_set_cost( actionplanner_t* ap, const char* actionname, int cost )
{
	const int actidx = idx_for_actionname( ap, actionname ); // Find or add the action index
	if ( actidx == -1 ) return false;                        // If index is invalid, return error
	ap->act_costs[ actidx ] = cost;                          // Set the cost for the action
	return true;
}

/*
 * @brief Generates a human-readable description of the world state.
 * This function formats the current world state into a string description.
 */
void goap_worldstate_description( const actionplanner_t* ap, const worldstate_t* ws, char* buf, int sz )
{
	int added=0;
	for ( int i=0; i<MAXATOMS; ++i )
	{
		if ( ( ws->dontcare & ( 1LL << i ) ) == 0LL ) // If we care about this atom
		{
			const char* val = ap->atm_names[ i ]; // Get the atom name

			// Check if val is null before proceeding
            if (val == NULL) {
				// LOGI( "Value is NULL" )
                continue;  // Skip this iteration if the atom name is null
            }

			// Convert atom name to uppercase
            char upval[128]; // Temporary buffer to store the uppercase name
            size_t j;
            for (j = 0; j < strlen(val); ++j)
                upval[j] = (val[j] - 32);  // Convert each character to uppercase

            upval[j] = 0;  // Null-terminate the uppercase string

            // Check if the value in the world state is set
            const bool set = ( ( ws->values & ( 1LL << i ) ) != 0LL );

            // Add the description to the buffer
            added = snprintf(buf, sz, "%s,", set ? upval : val);
            buf += added;  // Move buffer pointer forward
            sz -= added;   // Decrease buffer size
		}
	}
}

/**
 * @brief Generates a description of the action planner.
 * This function generates a description of each action's preconditions and postconditions.
 */
void goap_description(actionplanner_t* ap, char* buf, int sz)
{
    int added = 0;

    // Loop through all actions in the action planner
    for (int a = 0; a < ap->numactions; ++a)
    {
        // Print the name of the current action
        added = snprintf(buf, sz, "%s:\n", ap->act_names[a]);
        sz -= added;  // Decrease the buffer size after printing
        buf += added; // Move the buffer pointer forward

        // Get the preconditions and postconditions for this action
        worldstate_t pre = ap->act_pre[a];
        worldstate_t pst = ap->act_pst[a];

        // Loop through all possible world state atoms (preconditions)
        for (int i = 0; i < MAXATOMS; ++i)
        {
            // If the 'dontcare' flag for this atom is not set, process it
            if ((pre.dontcare & (1LL << i)) == 0LL)
            {
                // Check if the value is set or unset in the world state
                bool v = (pre.values & (1LL << i)) != 0LL;

                // Print the atom name and its value as a precondition (==)
                added = snprintf(buf, sz, "  %s==%d\n", ap->atm_names[i], v);
                sz -= added;  // Decrease the buffer size
                buf += added; // Move the buffer pointer forward
            }
        }

        // Loop through all possible world state atoms (postconditions)
        for (int i = 0; i < MAXATOMS; ++i)
        {
            // If the 'dontcare' flag for this atom is not set, process it
            if ((pst.dontcare & (1LL << i)) == 0LL)
            {
                // Check if the value is set or unset in the postcondition
                bool v = (pst.values & (1LL << i)) != 0LL;

                // Print the atom name and its value as a postcondition (: =)
                added = snprintf(buf, sz, "  %s:=%d\n", ap->atm_names[i], v);
                sz -= added;  // Decrease the buffer size
                buf += added; // Move the buffer pointer forward
            }
        }
    }
}

/*
 * @brief Applies the effects of an action to a world state.
 * This function simulates performing an action by updating the world state based on postconditions.
 */
static worldstate_t goap_do_action( actionplanner_t const* ap, int actionnr, worldstate_t fr )
{
	const worldstate_t pst = ap->act_pst[ actionnr ];  // Get the postcondition for the action
	const bfield_t unaffected = pst.dontcare;         // The atoms that aren't affected by the action
	const bfield_t affected   = ( unaffected ^ -1LL ); // The atoms that are affected by the action

	fr.values = ( fr.values & unaffected ) | ( pst.values & affected ); // Update the world state values
	fr.dontcare &= pst.dontcare; // Update the 'dontcare' flags
	return fr;
}

/*
 * @brief Retrieves possible state transitions based on available actions.
 * This function identifies actions whose preconditions match the current world state and returns the resulting states.
 */
int goap_get_possible_state_transitions( actionplanner_t const* ap, worldstate_t fr, worldstate_t* to, const char** actionnames, int* actioncosts, int cnt )
{
	int writer=0;
	for ( int i=0; i<ap->numactions && writer<cnt; ++i ) // Loop through all actions, stop if the writer index reaches the limit
	{
		// Check if the precondition is met
		const worldstate_t pre = ap->act_pre[ i ];
		const bfield_t care = ( pre.dontcare ^ -1LL );  // Atoms we care about in the precondition
		const bool met = ( ( pre.values & care ) == ( fr.values & care ) ); // Check if precondition is met
		if ( met ) // If precondition is satisfied
		{
			actionnames[ writer ] = ap->act_names[ i ];  // Store the action name
			actioncosts[ writer ] = ap->act_costs[ i ];  // Store the action cost
			to[ writer ] = goap_do_action( ap, i, fr );  // Perform the action and store the resulting state
			++writer;
		}
	}
	return writer; // Return the number of possible transitions found
}
