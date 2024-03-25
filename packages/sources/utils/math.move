module refund::math {
    public fun div(x: u64, y: u64): u64 {
        (x / y)
    }

    public fun mul_div(x: u64, y: u64, z: u64): u64 {
        let x = (x as u128);
        let y = (y as u128);
        let z = (z as u128);
        
        let result = (((x * y) / z) as u64);

        result
    }
}