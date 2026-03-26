console.log("Привет, мир");

const numbers = [1, 2, 3];
const sum = numbers.reduce((total, value) => total + value, 0);

console.log("Сумма:", sum);

setTimeout(() => {
    throw new Error("Это запланированная ошибка");
}, 10000);
