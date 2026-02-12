/**
 * Fetch resource name from the URL
 */
const getResourceName = () => {
  const url = window.location.href;
  const regex = /https?:\/\/cfx-nui-([^/]+)/;
  const match = url.match(regex);
  
  return match ? match[1] : 'sleepless_interact';
};

/**
 * Simple wrapper around fetch that sends messages to the NUI API
 * @param {string} eventName - The event name to target
 * @param {*} data - Data to send in the message body
 * @returns {Promise<*>} - Response data from the NUI callback
 */
export async function fetchNui(eventName, data) {
  const resourceName = getResourceName();
  // console.log(`Sending NUI message to ${resourceName}/${eventName}:`, data);
  
  try {
    const resp = await fetch(`https://${resourceName}/${eventName}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: JSON.stringify(data || {}),
    });
    
    const responseData = await resp.json();
    // console.log(`Received response from ${eventName}:`, responseData);
    return responseData;
  } catch (error) {
    // console.error(`Error in fetchNui (${eventName}):`, error.message);
    // Return a default response to prevent further errors
    return { error: true, message: error.message };
  }
}

// For debugging purposes
// console.log('Detected resource name:', getResourceName());
