const jwt = require("jsonwebtoken");
const db = require("../config/db");

async function findUserByPin(pin) {
  const query = `
    SELECT id, full_name, role_id, pin_code, is_active
    FROM users
    WHERE pin_code = $1
    LIMIT 1
  `;
  const { rows } = await db.query(query, [pin]);
  return rows[0] || null;
}

function signAccessToken(user) {
  return jwt.sign(
    {
      user_id: user.id,
      full_name: user.full_name,
      role_id: user.role_id,
    },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || "8h" }
  );
}

module.exports = {
  findUserByPin,
  signAccessToken,
};
